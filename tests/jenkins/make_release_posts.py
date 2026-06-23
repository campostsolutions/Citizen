# This script updates the post keywords for release to Fusion/InvCAM
# It is adapted from HSMWorks/make_release_posts.py

import os
import time
import datetime
import sys
import subprocess
import filecmp
import shutil
import re
import signal
import collections
import argparse

from multiprocessing import Pool

# Parse command line
parser = argparse.ArgumentParser(description='Build post library artifact')
parser.add_argument('--destination', type=str,
                   help='Destination folder, where to put result')

args = parser.parse_args()

DEBUG = False

def getScriptPath() -> str:
  return os.path.dirname(os.path.realpath(sys.argv[0]))

scriptFolder = getScriptPath()
srcFolder = os.path.join(scriptFolder, "..")

destinationFolder = args.destination

# Backward compatibility (can be removed when 3P catches on)
if not destinationFolder:
  destinationFolder = os.path.join(scriptFolder, "../../post-library-release")

def intro() -> None:
  print("Building post-library artifact")
  print("")

def error(text) -> None:
  print("Error: " + text, file=sys.stderr)
  sys.exit()

def debug(text) -> None:
  if DEBUG:
    print("Debug: " + text)

f = open(os.path.join(srcFolder, "revisionbase.txt"), "r")
REVISION_BASE = int(f.readline()) # base from SVN
f.close()
if REVISION_BASE <= 0:
  error("Invalid revision base")
  sys.exit()

class Entry:
  def __init__(self):
    self.changeId = None
    self.revision = None
    self.date = None
    self.author = None
    self.message = ""

# Returns all commits for the repository.
def getCommits() -> dict:
  debug("Getting all commits...")
  process = subprocess.Popen(["git", "-C", srcFolder, "rev-list", "HEAD"], stdout=subprocess.PIPE)
  data = process.stdout.read()
  code = process.wait()
  debug("Got exit code %d from git rev-list command." % code)
  if code != 0:
    error("Failed to get git rev-list from '%s'" % srcFolder)
    return {}

  data = data.decode("utf-8")
  
  commits = {}
  count = 1
  changeid = ""
  for line in reversed(data.splitlines()):
    changeid = line.strip()
    if changeid:
      commits[changeid] = count + REVISION_BASE
      count += 1

  return commits

# Returns the latest change for the given file.
def getLatestChange(path) -> Entry:
  #path = os.path.relpath(_path, srcFolder) # need path relative to repository root
  debug("Getting latest commit for '%s'..." % path)
  
  process = subprocess.Popen(["git", "-C", srcFolder, "log", "-n", "1", "--pretty=format:%H|%an|%ct|%s", path], stdout=subprocess.PIPE)
  data = process.stdout.read()
  code = process.wait()
  debug("Got exit code %d from git log command." % code)
  if code != 0:
    print("File is not in git: '%s'" % path)
    return None
  data = data.decode("utf-8")
  
  global commits
  lines = data.splitlines()
  if not lines:
    print("File is not in git: '%s'" % path)
    return None

  fields = lines[0].split("|")
  changeId = fields[0]
  author = fields[1]
  date = datetime.datetime.fromtimestamp(float(fields[2])).strftime("%Y-%m-%d %H:%M:%S")
  message = fields[3]
  
  if not changeId in commits:
    print("Commit '%s' not found for '%s'." % (changeId, path))
    return None
    
  revision = commits[changeId] # map commit to revision
  
  entry = Entry()
  entry.changeId = changeId
  entry.revision = revision
  entry.date = date
  entry.message = " ".join(message.split(" ")[1:])
  return entry

# Writes the given content if different from current file content.
def writeFile(data, destPath) -> None:
  with open(destPath, "w") as f:
    f.write(data)

def isCopiedToArtifact(filename) -> bool:
  if filename.endswith(".cps"):
    return True
  if filename.endswith(".css"):
    return True
  if filename.endswith(".lang"):
    return True
  if filename.endswith(".xls"):
    return True
  if filename.endswith(".xlsx"):
    return True
  return False

def processFile(filename) -> None:
  sourcePath = os.path.join(srcFolder, filename)
  destinationPath = os.path.join(destinationFolder, os.path.basename(sourcePath))
  latestChange = getLatestChange(filename)
  
  if not latestChange:
    return

  if filename.endswith(".xlsx") or filename.endswith(".xls"):
    shutil.copyfile(sourcePath, destinationPath)
    return

  versionString = str(latestChange.revision) + " " + latestChange.changeId
  with open(sourcePath, "r") as f:
    newData = f.read().\
      replace("$Commit$", "$Commit: " + latestChange.changeId + " $").\
      replace("$Revision$", "$Revision: " + versionString + " $").\
      replace("$Date$", "$Date: " + latestChange.date + " $")
    writeFile(newData, destinationPath)

class WorkerData(object):
  def __init__(self, commits):
    self.commits = commits

def initWorker(data) -> None:
  signal.signal(signal.SIGINT, signal.SIG_DFL)
  global commits
  commits = data.commits

def generateLibraryPostList(destinationFolder):
  includeListPath = os.path.join(srcFolder, "library_posts.txt")
  hiddenPosts = []
  publicPosts = []
  with open(includeListPath, "r") as f:
    for line in f:
      line = line.split("#")[0]
      line = line.strip()
      if line:
        words = line.split(";")
        if len(words) < 1:
          continue # nothing to parse
        name = words[0]

        if name.startswith("*"):
          name = name[1:]
          hiddenPosts.append(name)
        elif not name.startswith("-"):
          name = name[1:]
          publicPosts.append(name)
  destPath = os.path.join(destinationFolder, "posts.txt")
  with open(destPath, "w") as f:
    f.write("Public posts: \n")
    for post in publicPosts:
      f.write(post + "\n")
    f.write("\nHidden posts: \n")
    for post in hiddenPosts:
      f.write(post + "\n")

# Builds the release folder.
def buildLibrary() -> None:
  if __name__ != '__main__':
    return
  
  intro()
  
  # Ensure destination folder
  if not os.path.exists(destinationFolder):
    os.makedirs(destinationFolder)
  
  generateLibraryPostList(destinationFolder)

  signal.signal(signal.SIGINT, signal.SIG_DFL)
  workerData = WorkerData(getCommits())
  p = Pool(processes=8, initializer=initWorker, initargs=[workerData])
  
  # Take only cps,css,lang,xls*
  files = [f for f in os.listdir(srcFolder) if isCopiedToArtifact(f)]
  try:
    p.map(processFile, files)
  except KeyboardInterrupt:
    print("Terminated")
    p.terminate()
    sys.exit(0)
  else:
    p.close()
  p.join()
    
  print("Updated %d posts." % len(files))

buildLibrary()
