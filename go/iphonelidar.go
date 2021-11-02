// Package iphonelidar provides a command for viewing the output of iPhone's LiDAR camera
package main

import (
	"bufio"
	"context"
	//"encoding/json"
	//"errors"
	"fmt"
	"image"
	"image/color"
	"io"
	"io/ioutil"
	"math"
	"strings"
	//"log"
	"net/http"
	"path"
	"strconv"
	"sync"
	"sync/atomic"
	//"time"

	"go.viam.com/core/camera"
	"go.viam.com/core/config"
	"go.viam.com/core/pointcloud"
	"go.viam.com/core/registry"
	//"go.viam.com/core/rimage"
	"go.viam.com/core/robot"

	"github.com/edaniels/golog"
	"github.com/mitchellh/mapstructure"
	"go.viam.com/utils"
)

// A Measurement is a struct representing the data collected by the iPhone using the point clouds iPhone app.
type Measurement struct {
	PointCloud string `json:"poclo"`
	// rbg        [][3]float64 `json:"rbg"`
}

// IPhone is an iPhone based LiDAR camera.
type IPhone struct {
	Config      *Config       // The config struct containing the info necessary to determine what iPhone to connect to.
	readCloser  io.ReadCloser // The underlying response stream from the iPhone.
	reader      *bufio.Reader // Read connection to iPhone to pull lidar data from.
	log         golog.Logger
	mut         sync.Mutex // Mutex to ensure only one goroutine or thread is reading from reader at a time.
	lastError   error
	measurement atomic.Value // The latest measurement value read from reader.

	cancelCtx               context.Context
	cancelFn                func()
	activeBackgroundWorkers sync.WaitGroup
}

// Config is a struct used to configure and construct an IPhone using IPhone.New().
type Config struct {
	Host string // The host name of the iPhone being connected to.
	Port int    // The port to connect to.
}

const (
	DefaultPath = "/measurement"
	modelname   = "iphonelidar"
)

// init registers the iphone lidar camera.
func init() {
	fmt.Printf("hi1")
	registry.RegisterCamera(modelname, registry.Camera{
		Constructor: func(ctx context.Context, r robot.Robot, c config.Component, logger golog.Logger) (camera.Camera, error) {
			fmt.Printf("bye")
			// add conditionals to  make sure that json file was properly formatted
			iCam, err := New(ctx, Config{Host: "192.168.132.146", Port: 3000}, logger)
			//iCam, err := New(ctx, Config{Host: c.Host, Port: c.Port, logger)
			if err != nil {
				return nil, err
			}
			return &camera.ImageSource{iCam}, nil
		}})

	config.RegisterComponentAttributeMapConverter(config.ComponentTypeInputController, modelname, func(attributes config.AttributeMap) (interface{}, error) {
		var conf Config
		decoder, err := mapstructure.NewDecoder(&mapstructure.DecoderConfig{TagName: "json", Result: &conf})
		if err != nil {
			return nil, err
		}
		if err := decoder.Decode(attributes); err != nil {
			return nil, err
		}
		fmt.Println(conf)
		return &conf, nil
	})
}

// New returns a new IPhone that that pulls data from the iPhone defined in config.
func New(ctx context.Context, config Config, logger golog.Logger) (*IPhone, error) {
	fmt.Printf("hi1111")
	cancelCtx, cancelFn := context.WithCancel(context.Background())
	ip := IPhone{
		Config:                  &config,
		log:                     logger,
		mut:                     sync.Mutex{},
		cancelCtx:               cancelCtx,
		cancelFn:                cancelFn,
		activeBackgroundWorkers: sync.WaitGroup{},
	}

	err := ip.Config.tryConnection()
	if err != nil {
		ip.setLastError(err)
		return nil, fmt.Errorf("failed to connect to iphone %s on port %d: %v", config.Host, config.Port, err)
	}

	// Have a thread in the background constantly reading the latest camera readings from the iPhone
	ip.activeBackgroundWorkers.Add(1)
	utils.PanicCapturingGo(func() {
		defer ip.activeBackgroundWorkers.Done()
		for {
			select {
			case <-ip.cancelCtx.Done():
				return
			default:
			}
			_, _, err := ip.Next(ip.cancelCtx)
			if err != nil {
				// try connecting again
				reerr := ip.Config.tryConnection()
				if reerr != nil {
					ip.setLastError(err)
					return
					//return nil, fmt.Errorf("failed to connect to iphone %s on port %d: %v", config.Host, config.Port, err)
				}
				ip.setLastError(err)
				logger.Debugw("error reading iphone data", "error", err)
			}
		}
	})
	return &ip, nil
}

func (c *Config) tryConnection() error {
	portString := strconv.Itoa(c.Port)
	url := path.Join(c.Host+":"+portString, DefaultPath)
	resp, err := http.Get("http://" + url)
	if err != nil {
		return err
	}
	if resp.StatusCode != 200 {
		return fmt.Errorf("received non-200 status code when connecting: %d", resp.StatusCode)
	}
	return nil
}

func (ip *IPhone) NextPointCloud(ctx context.Context) (pointcloud.PointCloud, error) {
	ip.mut.Lock()
	defer ip.mut.Unlock()
	if ip.lastError != nil {
		return nil, ip.lastError
	}
	portString := strconv.Itoa(ip.Config.Port)
	url := path.Join(ip.Config.Host+":"+portString, DefaultPath)
	resp, err := http.Get("http://" + url)
	if err != nil {
		ip.setLastError(err)
		return nil, err
	}
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("received non-200 status code when connecting: %d", resp.StatusCode)
	}
	//We Read the response body on the line below.
	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		ip.setLastError(err)
		return nil, err
	}
	//Convert the body to type string
	sb := string(body)
	points := stringConverter(sb)

	pc := pointcloud.New()
	for i := 0; i < len(points); i++ {
		err := pc.Set(pointcloud.NewBasicPoint(points[i][0], points[i][1], points[i][3]).SetIntesnity(uint16(1)))
		if err != nil {
			ip.setLastError(err)
			return nil, err
		}
	}
	return pc, nil
}

func (ip *IPhone) Next(ctx context.Context) (image.Image, func(), error) {
	pc, err := ip.NextPointCloud(ctx)
	if err != nil {
		ip.setLastError(err)
		return nil, nil, err
	}

	minX := 0.0
	minY := 0.0

	maxX := 0.0
	maxY := 0.0

	pc.Iterate(func(p pointcloud.Point) bool {
		pos := p.Position()
		minX = math.Min(minX, pos.X)
		maxX = math.Max(maxX, pos.X)
		minY = math.Min(minY, pos.Y)
		maxY = math.Max(maxY, pos.Y)
		return true
	})

	width := 800
	height := 800

	scale := func(x, y float64) (int, int) {
		return int(float64(width) * ((x - minX) / (maxX - minX))),
			int(float64(height) * ((y - minY) / (maxY - minY)))
	}

	img := image.NewNRGBA(image.Rect(0, 0, width, height))

	set := func(xpc, ypc float64, clr color.NRGBA) {
		x, y := scale(xpc, ypc)
		img.SetNRGBA(x, y, clr)
	}

	pc.Iterate(func(p pointcloud.Point) bool {
		set(p.Position().X, p.Position().Y, color.NRGBA{255, 0, 0, 255})
		return true
	})

	centerSize := .1
	for x := -1 * centerSize; x < centerSize; x += .01 {
		for y := -1 * centerSize; y < centerSize; y += .01 {
			set(x, y, color.NRGBA{0, 255, 0, 255})
		}
	}

	return img, nil, nil
}

func (ip *IPhone) Close() error {
	ip.cancelFn()
	ip.activeBackgroundWorkers.Wait()
	return ip.readCloser.Close()
}

// returns e.g. = [[1.11 2.22 3.33] [4.44 5.55 666] [7.77 8.88 9.99]]
func stringConverter(s string) [][]float64 {
	npointcloud := strings.ReplaceAll(s, "[(", "")
	nnpointcloud := strings.ReplaceAll(npointcloud, ")]", "")
	point := strings.Split(nnpointcloud, "),(")
	l0 := make([][]float64, len(point))
	for i := 0; i < len(point); i++ {
		l := make([]float64, 3)
		new_point := strings.Split(point[i], ",")
		for j := 0; j < len(new_point); j++ {
			if j == 0 {
				if s, err := strconv.ParseFloat(new_point[j], 64); err == nil {
					l[0] = s
				}
			}
			if j == 1 {
				if s, err := strconv.ParseFloat(new_point[j], 64); err == nil {
					l[1] = s
				}
			}
			if j == 2 {
				if s, err := strconv.ParseFloat(new_point[j], 64); err == nil {
					l[2] = s
				}
			}
		}
		l0[i] = l
		//fmt.Printf("%T\n", l)
	}
	//fmt.Println(l0)
	return l0
}

func (ip *IPhone) setLastError(err error) {
	ip.mut.Lock()
	defer ip.mut.Unlock()
	ip.lastError = err
}
