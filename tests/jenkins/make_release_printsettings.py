# This script copies print settings files to the post-library-release/printsettings folder
# It is adapted from HSMWorks/make_release_posts.py

import os
import sys
import shutil
import argparse

# Parse command line
parser = argparse.ArgumentParser(description='Build print settings library for post-library artifact')
parser.add_argument('--destination', type=str,
                   help='Destination folder, where to put result')
args = parser.parse_args()

DEBUG = False

def getScriptPath() -> str:
  return os.path.dirname(os.path.realpath(sys.argv[0]))

scriptFolder = getScriptPath()
srcFolder = os.path.join(scriptFolder, "..")

destinationFolder = args.destination

if not destinationFolder:
  destinationFolder = os.path.join(scriptFolder, "../../post-library-release")


def intro() -> None:
  print("Building print setting library for post-library artifact")
  print("")

def error(text) -> None:
  print("Error: " + text, file=sys.stderr)
  sys.exit()

def warning(text) -> None:
  print("Warning: " + text)

def debug(text) -> None:
  if DEBUG:
    print("Debug: " + text)

# Writes the given content if different from current file content.
def writeFile(data, destPath) -> None:
  with open(destPath, "w") as f:
    f.write(data)

def isCopiedToArtifact(filename) -> bool:
  if filename.endswith(".printsetting"):
      return True
  if filename.endswith(".printSetting"):
      return True
  return False
#=============================================================================
# Collect list of files to copy recursively
#=============================================================================
def collectList(folder, outputList):
  debug("Folder: " + folder)
  for filename in sorted(os.listdir(folder)):
    fullPath = os.path.join(folder, filename)
    if os.path.isdir(fullPath):
      collectList(fullPath, outputList)
    if isCopiedToArtifact(filename):
      name = os.path.splitext(filename)[0]
      if name.startswith("."):
        warning("No filename (skipping " + filename + ")")
        continue
      
      # Don't add duplicates
      if fullPath not in outputList:
        outputList.append(fullPath)

#=============================================================================
def generateLibraryList(destinationFolder):
  allFiles = []
  collectList(srcFolder, allFiles)

  publicList = []
  hiddenList = []
  for path in allFiles:
    filename = os.path.basename(path)
    if path.lower().find('hidden') >= 0:
      hiddenList.append(filename)
    else:
      publicList.append(filename)
    # Copy files
    dest = os.path.join(destinationFolder, filename)
    shutil.copyfile(path, dest)

  destPath = os.path.join(destinationFolder, "printSetting.txt")
  with open(destPath, "w") as f:
    f.write("Public print settings: \n")
    for file in publicList:
      f.write(file + "\n")
    f.write("\nHidden print settings: \n")
    for file in hiddenList:
      f.write(file + "\n")


# Builds the release folder.
def buildLibrary() -> None:
  intro()

  # Ensure destination folder
  if not os.path.exists(destinationFolder):
    os.makedirs(destinationFolder)
  generateLibraryList(destinationFolder)


buildLibrary()
