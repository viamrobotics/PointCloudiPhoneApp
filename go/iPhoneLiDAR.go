// Package iPhoneLiDAR provides a command for viewing the output of iPhone's LiDAR camera
package iPhoneLiDAR

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"path"
	"strconv"
	"sync"
	"sync/atomic"
	"time"

	"go.viam.com/core/camera"
	"go.viam.com/core/config"
	"go.viam.com/core/registry"
	"go.viam.com/core/robot"
	"go.viam.com/utils"

	"github.com/edaniels/golog"
)

// A Measurement is a struct representing the data collected by the iPhone using
// the point clouds iPhone app.
type Measurement struct {
	PointCloud float64 `json:"poclo"`
}

// IPhone is an iPhone based LiDAR camera.
type IPhone struct {
	Config      *Config       // The config struct containing the info necessary to determine what iPhone to connect to.
	readCloser  io.ReadCloser // The underlying response stream from the iPhone.
	reader      *bufio.Reader // Read connection to iPhone to pull sensor data from.
	log         golog.Logger
	mut         sync.Mutex   // Mutex to ensure only one goroutine or thread is reading from reader at a time.
	measurement atomic.Value // The latest measurement value read from reader.

	cancelCtx               context.Context
	cancelFn                func()
	activeBackgroundWorkers sync.WaitGroup
}

// Config is a struct used to configure and construct an IPhone using IPhone.New().
type Config struct {
	Host      string // The host name of the iPhone being connected to.
	Port      int    // The port to connect to.
	isAligned bool   // are color and depth image already aligned
}

const (
	DefaultPath      = "/hello"
	defaultTimeoutMs = 1000
	model            = "iphone"
)

// init registers the iphone lidar camera.
func init() {
	registry.RegisterCamera("iPhoneLiDAR", registry.Camera{
		Constructor: func(ctx context.Context, r robot.Robot, c config.Component, logger golog.Logger) (camera.Camera, error) {
			iCam, err := New(ctx, Config{Host: c.Host, Port: c.Port, isAligned: c.isAligned}, logger)
			if err != nil {
				return nil, err
			}
			return &camera.ImageSource{iCam}, nil
		}})
}

func (ip *IPhone) Close() error {
	ip.cancelFn()
	ip.activeBackgroundWorkers.Wait()
	return ip.readCloser.Close()
}

// New returns a new IPhone that that pulls data from the iPhone defined in config.
// New creates a connection to a iPhone lidar and generates pointclouds from it
func New(ctx context.Context, config Config, logger golog.Logger) (*IPhone, error) {
	cancelCtx, cancelFn := context.WithCancel(context.Background())
	ip := IPhone{
		Config:                  &config,
		log:                     logger,
		mut:                     sync.Mutex{},
		cancelCtx:               cancelCtx,
		cancelFn:                cancelFn,
		activeBackgroundWorkers: sync.WaitGroup{},
	}
	r, rc, err := ip.Config.getNewReader()
	if err != nil {
		return nil, fmt.Errorf("failed to connect to iphone %s on port %d: %v", config.Host, config.Port, err)
	}
	ip.readCloser = rc
	ip.reader = r
	ip.measurement.Store(Measurement{})

	// Have a thread in the background constantly reading the latest sensor readings from the iPhone and saving
	// them to ip.measurement. This avoids the problem of our read accesses constantly being behind by bufSize bytes.
	ip.activeBackgroundWorkers.Add(1)
	utils.PanicCapturingGo(func() {
		defer ip.activeBackgroundWorkers.Done()
		for {
			select {
			case <-ip.cancelCtx.Done():
				return
			default:
			}
			pcReading, err := ip.readNextMeasurement(ip.cancelCtx)
			if err != nil {
				logger.Debugw("error reading iphone data", "error", err)
			} else {
				ip.measurement.Store(*pcReading)
			}
		}
	})

	return &ip, nil
}

// StartCalibration does nothing.
func (ip *IPhone) StartCalibration(ctx context.Context) error {
	return nil
}

// StopCalibration does nothing.
func (ip *IPhone) StopCalibration(ctx context.Context) error {
	return nil
}

func (c *Config) getNewReader() (*bufio.Reader, io.ReadCloser, error) {
	portString := strconv.Itoa(c.Port)
	url := path.Join(c.Host+":"+portString, DefaultPath)
	resp, err := http.Get("http://" + url)
	if err != nil {
		return nil, nil, err
	}
	if resp.StatusCode != 200 {
		return nil, nil, fmt.Errorf("received non-200 status code when connecting: %d", resp.StatusCode)
	}
	return bufio.NewReader(resp.Body), resp.Body, nil
}

// readNextMeasurement attempts to read the next line available to ip.reader. It has a defaultTimeoutMs
// timeout, and returns an error if no measurement was made available on ip.reader in that time or if the line did not
// contain a valid JSON representation of a Measurement.
func (ip *IPhone) readNextMeasurement(ctx context.Context) (*Measurement, error) {
	timeout := time.Now().Add(defaultTimeoutMs * time.Millisecond)
	wg := sync.WaitGroup{}
	ctx, cancel := context.WithDeadline(ctx, timeout)
	defer wg.Wait()
	defer cancel()

	ch := make(chan string, 1)
	wg.Add(1)
	utils.PanicCapturingGo(func() {
		defer wg.Done()
		ip.mut.Lock()
		defer ip.mut.Unlock()
		measurement, err := ip.reader.ReadString('\n')
		if err != nil {
			if err := ip.readCloser.Close(); err != nil {
				ip.log.Errorw("failed to close reader", "error", err)
			}
			// In the error case, it's possible we were disconnected from the underlying iPhone. Attempt to reconnect.
			r, rc, err := ip.Config.getNewReader()
			if err != nil {
				ip.log.Errorw("failed to connect to iphone", "error", err)
			} else {
				ip.readCloser = rc
				ip.reader = r
			}
		} else {
			ch <- measurement
		}
	})

	select {
	case measurement := <-ch:
		var imuReading Measurement
		err := json.Unmarshal([]byte(measurement), &imuReading)
		if err != nil {
			return nil, err
		}

		return &imuReading, nil
	case <-ctx.Done():
		return nil, errors.New("timed out waiting for iphone measurement")
	}
}
