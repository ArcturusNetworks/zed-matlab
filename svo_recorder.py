import pyzed.sl as sl
from signal import signal, SIGINT
import datetime
import os
import sys
import time

cam = sl.Camera()

rootDir = "Recordings"
os.makedirs(rootDir, exist_ok=True)
os.chdir(rootDir)

def handler(signal_received, frame):
    cam.disable_recording()
    cam.close()
    sys.exit(0)

signal(SIGINT, handler)

def main():
    init = sl.InitParameters()
    init.camera_resolution = sl.RESOLUTION.HD720
    init.camera_fps = 15
    init.depth_mode = sl.DEPTH_MODE.PERFORMANCE

    status = cam.open(init)
    if status != sl.ERROR_CODE.SUCCESS:
        print(repr(status))
        exit(1)

    now = datetime.datetime.now()
    filename = f'{now.year}_{now:%b}_{now:%d}_{now:%a}_{now:%H}_{now:%M}.svo'
    recording_param = sl.RecordingParameters(filename, sl.SVO_COMPRESSION_MODE.H264)
    err = cam.enable_recording(recording_param)
    if err != sl.ERROR_CODE.SUCCESS:
        print(repr(status))
        exit(1)

    runtime = sl.RuntimeParameters()
    print("SVO is Recording, use Ctrl-C to stop.")
    frames_recorded = 0

    while True:
        if cam.grab(runtime) != sl.ERROR_CODE.SUCCESS:
            cam.disable_recording()
            cam.close()
            break

        frames_recorded += 1
        print(f"Frame count: {frames_recorded}")
        time.sleep(1)
        
    print("Finished recording")

if __name__ == "__main__":
    main()