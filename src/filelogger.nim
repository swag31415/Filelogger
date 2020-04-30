## FileLogger

import os
import json

type
  J_Thing = object of RootObj
    name: string
    size: BiggestInt
  J_File = object of J_Thing
    ext: string
  J_Folder = object of J_Thing
    folders: seq[J_Folder]
    files: seq[J_File]

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
      of pcFile: # If its a file
        let (dir, name, ext) = splitFile(path) # Get its name and extension
        let size = getFileSize(path) # Get its size
        result.files.add(J_File(name:name, ext:ext, size:size)) # Convert it to a J_File and add it to the seq
        result.size += size # Track its size
      else: discard # Don't worry about symblinks and stuff

# Saves the provided J_Folder to JSON. Conversion is done with ``%*``
proc save_as_json(folder: J_Folder; pretty = true) =
  if (pretty): writeFile(folder.name & "_data.json", (%*folder).pretty())
  else: writeFile(folder.name & "_data.json", $(%*folder))