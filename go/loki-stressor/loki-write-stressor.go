package main

import (
	"bytes"
	"flag"
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"os"
	"time"
)

const minBurstMessageCount = 100
const numberOfBursts = 10

const letterBytes = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

func RandStringBytes(n int) string {
	b := make([]byte, n)
	for i := range b {
		b[i] = letterBytes[rand.Intn(len(letterBytes))]
	}
	return string(b)
}

func main() {

	var payloadSize int
	var messagesPerSecond int
	var burstSize int
	var endPoint string
    var labels string

	flag.IntVar(&payloadSize, "payloadSize", 100, "Payload length [int]")
	flag.IntVar(&messagesPerSecond, "messagesPerSecond", 1, "Number of messages per second")
	flag.IntVar(&burstSize, "burstSize", 1, "Number of messages in a burst")
	flag.StringVar(&endPoint, "endPoint", "http://localhost:3100/api/prom/push", "Loki push endPoint")
    flag.StringVar(&labels, "labels", "{\"foo\"=\"bar\"}", "Loki labels")

	flag.Parse()
	rand.Seed(time.Now().UnixNano())

	log.Printf("INFO: payloadSize %d", payloadSize)
	log.Printf("INFO: messagesPerSecond %d", messagesPerSecond)
	log.Printf("INFO: burstSize %d", burstSize)
	log.Printf("INFO: endPoint %s", endPoint)
	log.Printf("INFO: labels %s", labels)

	if burstSize > messagesPerSecond {
	    burstSize = messagesPerSecond
        log.Printf("burstSize can't be bigger than messagesPerSecond, setting to %d", messagesPerSecond)
    }

	messageCount := 0
	hostname := os.Getenv("HOSTNAME")
	startTime := time.Now().Unix() - 1
	for {
		entries := ""
		for i := 0; ; {
			payload := RandStringBytes(payloadSize)
			now := time.Now().Format(time.RFC3339Nano)
			entries += fmt.Sprintf("{\"ts\":\"%v\",\"line\":\"host: %s message: %s\"}", now, hostname, payload)
			messageCount++
			i++
			if i >= burstSize {
				break
			}
			entries += ","
		}

		data:= fmt.Sprintf("{\"streams\": [{\"labels\": \"%s\",\"entries\": [%s]}]}", labels, entries)
		body := bytes.NewBuffer([]byte(data))

		_, err := http.Post(endPoint, "application/json", body)
		if err != nil {
			log.Printf("Got error Posting to Loki: %v", err)
		}

		sleep := 1.0 / float64( messagesPerSecond / burstSize)
		deltaTime := int(time.Now().Unix() - startTime)

		messagesPostedPerSec := messageCount / deltaTime
		if messagesPostedPerSec >= messagesPerSecond {
			time.Sleep(time.Duration(sleep * float64(time.Second)))
		}
	}
}
