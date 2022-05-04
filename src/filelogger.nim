## FileLogger

import os
import json
import utils # Import the loading bar
import viewerhtml
import times

type
  J_Thing = object of RootObj
    name: string
    size: BiggestInt
    made: string
    last: string
  J_File = object of J_Thing
    ext: string
  J_Folder = object of J_Thing
    folders: seq[J_Folder]
    files: seq[J_File]

const time_fmt = "MMM d UUUU H:mm:ss:fffffffff"
const n_steps = 20
var log_thread: Thread[void]
var log_chan: Channel[int]
var count_thread: Thread[string]

proc count_loop(dir: string) {.thread.} =
  for f in walkDirRec(dir):
    log_chan.send(0)

proc log_loop() {.thread.} =
  var total, done: BiggestInt
  while true:
    case log_chan.recv():
     of 0: total += 1
     of 1: done += 1
     else: break
    show_loading_bar(done, total, n_steps)

# Converts the provided dir into a J_Folder
proc get_folder(dir: string): J_Folder =
  result = J_Folder(name:lastPathPart(dir)) # Make a new J_Folder object
  for kind, path in walkDir(dir): # For every file and folder in the dir
    if isHidden(path): continue # Ignore hidden stuff
    case kind:
      of pcDir: # If its a dir
        let subdir = get_folder(path) # Recursively turn it into a J_Folder
        result.folders.add(subdir) # Add it to the folders seq
        result.size += subdir.size # Track its size
        log_chan.send(1)
      of pcFile: # If its a file
        let (dir, name, ext) = splitFile(path) # Get its name and extension
        var info: os.FileInfo
        try:
          info = getFileInfo(path) # Get its size
        except OSError as e:
          info = os.FileInfo()
        result.files.add(J_File(name:name, ext:ext, size:info.size, made:info.creationTime.format(time_fmt), last:info.lastWriteTime.format(time_fmt))) # Convert it to a J_File and add it to the seq
        result.size += info.size # Track its size
        log_chan.send(1)
      else: discard # Don't worry about symblinks and stuff

# Saves the provided J_Folder to JSON. Conversion is done with ``%*``
proc save_as_json(folder: J_Folder; pretty = true) =
  let J = %*folder
  if (pretty): writeFile(folder.name & "_data.json", J.pretty())
  else: writeFile(folder.name & "_data.json", $J)
  writeViewer("data_visualizer", $J)

when isMainModule:
  let current_dir = getCurrentDir() # The directory the compiled binary is in
  try:
    log_chan.open() # Open the channel
    createThread(log_thread, log_loop) # Create the loading bar thread
    createThread(count_thread, count_loop, current_dir)
    current_dir.get_folder().save_as_json() # Begin the file logging
  except CatchableError as e:
    echo e.msg
  finally: # When it's done or it errors out
    stdout.flushFile() # Flush all prints to the terminal
    log_chan.send(-1) # close the loading bar thread
    log_chan.close() # Close the channel
  echo "all done"