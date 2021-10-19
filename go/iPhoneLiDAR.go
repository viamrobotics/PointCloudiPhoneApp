// Package iPhoneLiDAR provides a command for viewing the output of iPhone's LiDAR camera
package iPhoneLiDAR

import (
	"bufio"
	"context"
	"image"
	"io"
	"sync"
	"sync/atomic"

	"github.com/edaniels/golog"

	"go.viam.com/core/camera"
	"go.viam.com/core/config"
	"go.viam.com/core/pointcloud"
	"go.viam.com/core/registry"
	"go.viam.com/core/robot"
)

// IPhone is an iPhone based IMU.
type iphone struct {
	Config *Config // The config struct containing the info necessary to determine what iPhone to connect to.

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
	Host string // The host name of the iPhone being connected to.
	Port int    // The port to connect to.
}

func init() {
	registry.RegisterCamera("iphoneLidar", registry.Camera{Constructor: func(ctx context.Context, r robot.Robot, config config.Component, logger golog.Logger) (camera.Camera, error) {
		//return &iphone{Name: config.Name}, nil
	}})
}

// Next always returns the same image with a red dot in the center.
func (c *iphone) Next(ctx context.Context) (image.Image, func(), error) {
	//
}

// NextPointCloud always returns a pointcloud with a single pixel
func (c *iphone) NextPointCloud(ctx context.Context) (pointcloud.PointCloud, error) {
	//

}

// Close does nothing.
func (c *iphone) Close() error {
	return nil
}
