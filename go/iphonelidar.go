// Package iphonelidar provides a command for viewing the output of iPhone's LiDAR camera
package iphonelidar

import (
	//"bufio"
	"context"
	"encoding/json"
	//"reflect"
	//"errors"
	"fmt"
	"image"
	"image/color"
	"io"
	"log"
	"math"
	"net/http"
	"path"
	"strconv"
	"strings"
	"sync"
	//"sync/atomic"
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

// IPhone is an iPhone based camera.
type IPhoneCam struct {
	Config     *Config       // The config struct containing the info necessary to determine what iPhone to connect to.
	readCloser io.ReadCloser // The underlying response stream from the iPhone.
	//reader      *bufio.Reader // Read connection to iPhone to pull data from.
	log golog.Logger
	mut sync.Mutex // Mutex to ensure only one goroutine or thread is reading from reader at a time.
	//	lastError error
	//measurement atomic.Value // The latest measurement value read from reader.

	cancelCtx               context.Context
	cancelFn                func()
	activeBackgroundWorkers sync.WaitGroup
}

type iPConfig struct {
	Host string `json:"host"` // The host name of the iPhone being connected to.
	Port int    `json:"port"` // The port to connect to.

}

type Config struct {
	Host string // The host name of the iPhone being connected to.
	Port int    // The port to connect to.
}

const (
	//DefaultPath = "/measurementstream"
	DefaultPath = "/measurement"
	modelname   = "iphonelidar"
)

// init registers the iphone lidar camera.
func init() {
	registry.RegisterCamera(modelname, registry.Camera{Constructor: func(ctx context.Context, r robot.Robot, c config.Component, logger golog.Logger) (camera.Camera, error) {
		iCam, err := New(ctx, r, Config{Host: c.ConvertedAttributes.(*iPConfig).Host, Port: c.ConvertedAttributes.(*iPConfig).Port}, logger)
		if err != nil {
			return nil, err
		}
		return iCam, nil
	}})
	config.RegisterComponentAttributeMapConverter(config.ComponentTypeCamera, modelname, func(attributes config.AttributeMap) (interface{}, error) {
		var conf iPConfig
		decoder, err := mapstructure.NewDecoder(&mapstructure.DecoderConfig{TagName: "json", Result: &conf})
		if err != nil {
			return nil, err
		}
		if err := decoder.Decode(attributes); err != nil {
			return nil, err
		}
		return &conf, nil
	}, &iPConfig{})
}

// New returns a new IPhone that that pulls data from the iPhone defined in config.
func New(ctx context.Context, r robot.Robot, config Config, logger golog.Logger) (camera.Camera, error) {
	cancelCtx, cancelFn := context.WithCancel(context.Background())

	ip := IPhoneCam{
		Config:                  &config,
		log:                     logger,
		mut:                     sync.Mutex{},
		cancelCtx:               cancelCtx,
		cancelFn:                cancelFn,
		activeBackgroundWorkers: sync.WaitGroup{},
	}

	err := ip.Config.tryConnection()
	if err != nil {
		//ip.setLastError(err)
		return nil, fmt.Errorf("failed to connect to iphone %s on port %d: %v", config.Host, config.Port, err)
	}

	// Have a thread in the background constantly reading the latest camera readings from the iPhone???
	ip.activeBackgroundWorkers.Add(1)
	utils.PanicCapturingGo(func() {
		defer ip.activeBackgroundWorkers.Done()
		for {
			select {
			case <-ip.cancelCtx.Done():
				return
			default:
			}
			err := ip.Config.tryConnection()
			if err != nil {
				//ip.setLastError(err)
				logger.Debugw("error reading iphone data", "error", err)
				ip.Close()
			}
		}
	})
	return &ip, nil
}

func (c *Config) tryConnection() error {
	portString := strconv.Itoa(c.Port)
	url := path.Join(c.Host+":"+portString, "/hello")
	resp, err := http.Get("http://" + url)
	if err != nil {
		return err
	}
	if resp.StatusCode != 200 {
		return fmt.Errorf("received non-200 status code when connecting: %d", resp.StatusCode)
	}
	return nil
}

func (ip *IPhoneCam) NextPointCloud(ctx context.Context) (pointcloud.PointCloud, error) {

	// if ip.lastError != nil {
	// 	return nil, ip.lastError
	// }

	portString := strconv.Itoa(ip.Config.Port)
	url := path.Join(ip.Config.Host+":"+portString, DefaultPath)
	resp, err := http.Get("http://" + url)
	if err != nil {
		//ip.setLastError(err)
		return nil, err
	}
	//defer resp.Body.Close()
	ip.readCloser = resp.Body
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("received non-200 status code when connecting: %d", resp.StatusCode)
	}
	//We read the response body on the line below.
	var measurement Measurement
	errr := json.NewDecoder(resp.Body).Decode(&measurement)
	if errr != nil {
		log.Fatalln(err)
	}

	sb := measurement.PointCloud
	//log.Println("type of sb is: ", reflect.TypeOf(sb))
	//log.Println(sb)
	points := stringConverter(sb)
	pc := pointcloud.New()
	//log.Println(points)
	//log.Println("type of pc is: ", reflect.TypeOf(pc))
	for i := 0; i < len(points); i++ {
		//log.Println(points[i][0])
		//log.Println(points[i][1])
		//log.Println(points[i][2])
		err := pc.Set(pointcloud.NewBasicPoint(points[i][0], points[i][1], points[i][2]))
		if err != nil {
			//ip.setLastError(err)
			return nil, err
		}
	}
	// pc.Iterate(func(p pointcloud.Point) bool {
	// 	pos := p.Position()
	// 	log.Println(pos)
	// 	return true
	// })
	//log.Println(pc.Size())
	//log.Println("cool")
	return pc, nil
}

func (ip *IPhoneCam) Next(ctx context.Context) (image.Image, func(), error) {
	ip.mut.Lock()
	defer ip.mut.Unlock()
	//log.Println("called Next!")
	pc, err := ip.NextPointCloud(ctx)
	if err != nil {
		//ip.setLastError(err)
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

	width := 1920
	height := 1440

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
	//log.Println("Next() img")
	return img, nil, nil
}

// returns e.g. = [[1.11 2.22 3.33] [4.44 5.55 666] [7.77 8.88 9.99]]
func stringConverter(s string) [][]float64 {
	ss := s[2:]
	sss := ss[:len(ss)-2]

	point := strings.Split(sss, "), (")

	l0 := make([][]float64, len(point))
	for i := 0; i < len(point); i++ {
		l := make([]float64, 3)

		new_point := strings.Split(point[i], ", ")
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
	}
	return l0
}

// func (ip *IPhoneCam) setLastError(err error) {
// 	ip.mut.Lock()
// 	defer ip.mut.Unlock()
// 	ip.lastError = err
// }

func (ip *IPhoneCam) Close() error {
	ip.cancelFn()
	ip.activeBackgroundWorkers.Wait()
	return ip.readCloser.Close()
}
