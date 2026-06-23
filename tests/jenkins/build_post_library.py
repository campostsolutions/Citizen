#!/usr/bin/python3
# -*- coding: utf-8 -*-
#
# This script build the post library intended for publication on our website
#
# Copyright (C) 2012-2020 by Autodesk, Inc.
# All rights reserved.

import os
import time
import datetime
import sys
import subprocess
import zipfile
import filecmp
import shutil
import re
import hashlib
import threading
import codecs
import signal
import json
import string

from io import StringIO

from multiprocessing import Pool

import argparse

from git_utils import *

# Parse command line
parser = argparse.ArgumentParser(description='Build post library')
parser.add_argument('--reference', type=str,
                   help='Reference posts.json from previous build')
parser.add_argument('--destination', type=str,
                   help='Destination folder, where to put result')

args = parser.parse_args()

DEBUG = False

approvedCharsForPostName = string.ascii_letters + string.digits + "-+ ()"

def getScriptPath():
  return os.path.dirname(os.path.realpath(sys.argv[0]))

scriptFolder = getScriptPath()
rootFolder = scriptFolder
dataFolder = os.path.join(rootFolder, "toolpath")
cpsFolder = os.path.join(rootFolder, "..")

jsonFolder = os.path.join(rootFolder, "json") # interrogation results
cppFolder = os.path.join(rootFolder, "cpp") # for post analytics whitelist

if args.destination:
  distFolder = args.destination
else:
  distFolder = os.path.join(rootFolder, "dist")

changesFolder = os.path.join(distFolder, "changes")
sampleFolder = os.path.join(distFolder, "samples")
rssFolder = os.path.join(distFolder, "rss")
rssVendorsFolder = os.path.join(rssFolder, "vendors")
previousVersionsFolder = os.path.join(distFolder, "previous versions")
previousVersionsLogFolder = os.path.join(previousVersionsFolder, "changes")
machineConnectorFolder = os.path.join(distFolder, "machine_connectors")

mutex = threading.Lock()

def readFile(path, mode="r"):
  with open(path, mode) as f:
    return f.read()
  
def loadJSON(path):
  try:
    res = json.loads(readFile(path))
  except:
    error("Failed to load JSON file")
  return res

defaultRevision = 41000

def loadReferenceDb():
  if args.reference:
    refDb = loadJSON(args.reference)
    refPosts = map(lambda r: r['filename'], refDb)
    recent = max(refDb, key=lambda r: r['revision'])
    return (recent['revision'], refPosts)
  return (defaultRevision, [])
  
def intro():
  print("Autodesk CAM Post Processor Library")
  print("")
  subprocess.call(["post", "--version"])
  print("")

def writeFile(path, data, mode="w"):
  with open(path, mode) as f:
    f.write(data)

def writeMessage(text):
  mutex.acquire()
  print(text)
  mutex.release()
  
def error(text):
  writeMessage("Error: " + text)
  sys.exit(1)

def writeProgress(text):
  writeMessage(text)
  
def debug(text):
  if DEBUG:
    writeMessage(f"Debug: {text}")

def error2(task, text):
  writeMessage("Error[%s]: %s\n" % (task, text))

def debug2(task, text):
  if DEBUG:
    writeMessage("DEBUG[%s]: %s" % (task, text))
    
# Returns the digest for the given data using SHA256.
def digestData(data):
  d = hashlib.sha256()
  d.update(data)
  return d.hexdigest()

# Returns the digest for the given file using SHA1.
def digestFile(path, digest="sha256"):
  d = hashlib.sha1()
  
  try:
    size = os.path.getsize(path)
    offset = 0

    with open(path, "rb") as f:
      for chunk in iter(lambda: f.read(4 * 64 * 1024), b""):
        offset += len(chunk)
        d.update(chunk)
  except KeyboardInterrupt:
    sys.exit(0)
  except:
    error("Failed to read file.")
  return d.hexdigest()

REVISION_BASE = int(readFile(os.path.join(cpsFolder, "revisionbase.txt"))) # base from SVN

if REVISION_BASE <= 0:
  error("Invalid revision base")

class Entry:
  def __init__(self):
    self.commitID = "" 
    self.revision = None
    self.date = None
    self.messages = []
    self.excluded = False
    self.fileHash = ""
    
class Message:
  def __init__(self, type, message) -> None:
    self.type = type
    self.message = message

def writeFileFromCommit(commitish, file, destination, change):
  out, code, err = readFileFromCommit(commitish, file)

  if code == 0:
    try:
      out = annotatePost(file, out.decode(), change).encode()
    except UnicodeDecodeError:
      # Some commits had encoding errors
      pass

    writeFile(destination, out, "wb")
  
  return code

# Returns all commits for the repository.
def getCommits():
  debug("Getting all commits...")
  commits = {}

  # Get archive of commits
  with open(os.path.join(scriptFolder, "revision-archive.txt")) as archive:
    for line in archive.readlines():
      latestCommit, revision = line.strip().split(':')
      commits[latestCommit] = int(revision)
  
  revision = int(revision)

  # Get list of revision tags
  (code, out, err) = runGit(['git', '-C', cpsFolder, 'tag', '--merged'])
  if code != 0: 
    error('Failed to get tags')

  # Get commits for each tag
  for tag in out.splitlines():
    tagCommits, latestCommit, revision = getTagCommits(tag, latestCommit)
    commits.update(tagCommits)

  # Get commits for latest revision
  currentChanges = getCommitRange(latestCommit, 'HEAD')
  commits.update({commit: revision+1 for commit in currentChanges})

  return commits

def getTagCommits(tag, startCommit):
  revision = int(tag[1:])
  code, tagTarget, err = runGit(['git', 'rev-list', '-1', f'tags/{tag}'])
  if code != 0:
    error(f'Failed to rev-list tag:{tag}')
    
  tagTarget = tagTarget.strip()
  revCommits = getCommitRange(startCommit, tagTarget)
  
  commits = {commit: revision for commit in revCommits}
  
  return commits, tagTarget, revision

def getCommitRange(startCommit, endCommit):
  code, commits, err = runGit(['git', 'rev-list', '--reverse', f'{startCommit}..{endCommit}'])
  if code != 0:
    error(f'Failed to rev-list commits {startCommit}..{endCommit}')
  return commits.splitlines()

# all commits from HEAD used to determine revisions
commits = getCommits()

def getGitLog(filePath):
  '''
  Returns the git commit log for the given file. The returned object is a list of
  log entry dicts. Each entry contains: 
  'commitID' commit id
  'author' commit author
  'date' commit date & time formatted YYYY-mm-dd HH:MM:SS
  'message' commit message
  'revision' post library revision at commitID
  '''
  # need path relative to repository root
  relPath = os.path.relpath(filePath, cpsFolder)
  debug(f"Getting commit log for '{relPath}'...")
  code, data, err = runGit(["git", "-C", cpsFolder, "log", "--since", "2013-9-01", "--pretty=format:%H|%an|%ct|%B|*|", relPath])
  debug(f"Got exit code {code} from git log command.")
  if code != 0:
    debug(err)
    error(f"Failed to get git log from '{relPath}'")
    return

  entries = []
  lines = data.split("|*|") # make sure we use a unique separator
  for line in lines:
    if not line:
      continue
    fields = line.split("|")
    if not fields:
      continue
    
    logEntry = {}
    try:
      logEntry['commitID'] = fields[0].strip()
      logEntry['author'] = fields[1].strip()
      logEntry['date'] = datetime.datetime.fromtimestamp(int(fields[2].strip()), datetime.timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
      logEntry['message'] = fields[3].strip()
    except:
      error2(filePath, "Got bad line '%s'" % line)
      continue

    # map commit to revision
    if not logEntry['commitID'] in commits:
      writeMessage(f"[Warning] getGitLog: Commit {logEntry['commitID']} not found for '{relPath}'.")
      continue

    logEntry['revision'] = commits[logEntry['commitID']]

    entries.append(logEntry)
  return entries

anyRe = re.compile("(FIX|NEW|CHG|LIBFIX|LIBNEW|LIBCHG).* .*")
fixRe = re.compile("(FIX|LIBFIX)(#(CAM.*-)?[0-9]+(,(CAM.*-)?[0-9]+)*)?(r[0-9]+)?[^ ]* .+")
newRe = re.compile("(NEW|LIBFIX)(#(CAM.*-)?[0-9]+(,(CAM.*-)?[0-9]+)*)?(r[0-9]+)?[^ ]* .+")
chgRe = re.compile("(CHG|LIBFIX|LIBCHG)(#(CAM.*-)?[0-9]+(,(CAM.*-)?[0-9]+)*)?(r[0-9]+)?[^ ]* .+")

def createEntry(_path, logEntry):
  name = os.path.splitext(os.path.basename(_path))[0] # Get the post name from the file
  
  entry = Entry()
  entry.commitID = logEntry['commitID']
  entry.revision = logEntry['revision']
  entry.date = logEntry['date']
  
  excluded = name in excludedRevisions and logEntry['revision'] in excludedRevisions[name]
  entry.excluded = excluded
  
  try:
    # Read post as it was at commitID
    postData, code, err = readFileFromCommit(logEntry['commitID'], os.path.basename(_path))
    if code == 0:
      annotatedPost = annotatePost(_path, postData.decode(), entry)
      entry.fileHash = digestData(annotatedPost.encode())
    else:
      writeMessage(f"Warning: Failed to read '{name}' from {entry.commitID}")
      debug(err)
      raise Exception
  except UnicodeDecodeError:
    # Some commits have encoding errors
    pass
  
  return entry

def parseLogEntries(_path, logEntries):
  entries = {} # Array of entries for this commit
  for logEntry in logEntries:
    # If we already have an entry, we just need to append a new message
    if logEntry['revision'] not in entries:
      # Not found, make a new one
      try:
        entries[logEntry['revision']] = createEntry(_path, logEntry)
      except:
        continue
      
    entry = entries[logEntry['revision']]
    
    for m in logEntry['message'].splitlines():
      if not anyRe.match(m):
        continue # ignore entry

      if DEBUG:
        print(entry.commitID, entry.excluded, entry.revision, entry.date, entry.fileHash)

      message = " ".join(m.split(" ")[1:]).strip()

      if fixRe.match(m):
        entry.messages.append(Message('FIX', message))
        debug(f'CHG: {message[0:30]}')
      elif newRe.match(m):
        entry.messages.append(Message('NEW', message))
        debug(f'CHG: {message[0:30]}')
      elif chgRe.match(m):
        entry.messages.append(Message('CHG', message))
        debug(f'CHG: {message[0:30]}')

  return entries.values()

# Returns the changes for the given file.
def getChanges(_path):
  gitLog = getGitLog(_path)
  entries = parseLogEntries(_path, gitLog)
  return sorted(entries, key=lambda entry: entry.revision, reverse=True) # sort by revision

def getHashLog(filePath):
  fileName = os.path.basename(filePath)
  gitLog = getGitLog(filePath)

  if len(gitLog) == 0:
    writeMessage(f"Failed to get git log for '{fileName}'")
  
  hashes = {}
  for logEntry in gitLog:
    
    postData, code, err = readFileFromCommit(logEntry['commitID'], fileName)
    if code != 0:
      writeMessage(f"Warning: Failed to read '{fileName}' from commit {logEntry['commitID']}")
      break

    # Build minimum change entry for annotation
    entry = Entry()
    entry.commitID = logEntry['commitID']
    entry.revision = logEntry['revision']
    entry.date = logEntry['date']
    try:
      annotatedPost = annotatePost(filePath, postData.decode(), entry)
      fileHash = digestData(annotatedPost.encode())
      hashes[logEntry['revision']] = fileHash
    except UnicodeDecodeError:
      # Some commits have encoding errors
      continue

  return hashes

def fixText(value):
  res = value.replace('\xE2\x80\xA6', "...")
  res = res.replace('\xE2\x80\x9C', "\"")
  return res.replace('\xE2\x80\x9D', "\"")

def makeRSS(items, filename=None):
  from email.utils import formatdate
  import urllib
  
  EOL = "\n"
  now = datetime.datetime.now(datetime.timezone.utc)
  
  result = '<?xml version="1.0" encoding="UTF-8"?>' + EOL
  result += '<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">' + EOL
  result += '<channel>' + EOL
  result += '<title>Autodesk HSM - Post Library</title>' + EOL
  result += '<description>Recent changes in the Autodesk HSM Post Library.</description>' + EOL
  result += '<link>https://cam.autodesk.com/posts</link>' + EOL
  result += '<copyright>Copyright 2020 by Autodesk, Inc.</copyright>' + EOL
  result += '<language>en-us</language>' + EOL
  result += ('<lastBuildDate>%s</lastBuildDate>' % formatdate(time.mktime(now.timetuple()))) + EOL
  result += ('<pubDate>%s</pubDate>' % formatdate(time.mktime(now.timetuple()))) + EOL
  atomLink = "https://cam.autodesk.com/posts/rss.php"
  if filename:
    atomLink += "?name=" + filename
  result += ('<atom:link href="%s" rel="self" type="application/rss+xml"/>' % atomLink) + EOL

  items.sort(reverse=True)
  for version, title, filename, messages, link, pub in items:
    dt = formatdate(time.mktime(pub.timetuple()))
    result += '<item>' + EOL
    result += ('<title>%s v%d</title>' % (title, version)) + EOL
    result += '<description><![CDATA['
    for message in messages:
      result += f'<p><b>{message.type}</b> {fixText(message.message)}</p>'
    result += ']]></description>' + EOL
    result += ('<link>%s</link>' % link) + EOL
    result += ('<pubDate>%s</pubDate>' % (dt)) + EOL
    result += '</item>' + EOL

  result += '</channel>' + EOL
  result += '</rss>' + EOL
  return result
  
class EncodeEntry(json.JSONEncoder):

  def default(self, o):
    return o.__dict__

# Synchronizes the specified files.
def syncFile(src, dest):
  if os.path.isfile(dest):
    if not filecmp.cmp(src, dest):
      shutil.copyfile(src, dest)
  else:
    shutil.copyfile(src, dest)

# Writes the given content if different from current file content.
def writeIfDifferent(data, destPath):
  store = True
  if os.path.exists(destPath):
    currentData = readFile(destPath)
    if data == currentData:
      store = False
  if store:
    debug("Updating file content for '%s'." % destPath)
    writeFile(destPath, data)
  return store

hiddenPosts = []
excludedPosts = []
includedPosts = []
machineConnectorNames = {}
videoUrls = {}
guideUrls = {}
redirections = {}

excludedRevisions = {}

null = open(os.devnull, "w")
now = datetime.datetime.now(datetime.timezone.utc)

# Process given post.
def processSamples(record, post, cpsPath):
  skipSample = False
  samplePath = os.path.splitext(cpsPath)[0] + ".pdf"
  if os.path.exists(samplePath):
    filename = os.path.splitext(os.path.basename(cpsPath))[0] + ".pdf"
    record['pdfsample'] = filename
    syncFile(samplePath, os.path.join(sampleFolder, filename))
    skipSample = True

  samples = []
  if not skipSample and 'capabilities' in record:
    if 'JET' in record['capabilities']:
      samples.append("sample_waterjet_computer.cnc")
      samples.append("sample_laser_computer.cnc")
      samples.append("sample_plasma_computer.cnc")
      samples.append("sample_waterjet.cnc")
      samples.append("sample_laser.cnc")
      samples.append("sample_plasma.cnc")
    if 'TURNING' in record['capabilities']:
      samples.append("sample_turning.cnc")
      if 'MILLING' in record['capabilities']:
        # TAG: add mill turn example
        samples.append("sample2d.cnc")
        samples.append("sample2d_simplified.cnc")
    elif 'MILLING' in record['capabilities']: # too slow for XZC mode for mill-turn
      samples.append("sample5x.cnc")
      samples.append("sample3d.cnc")
      samples.append("sample2d.cnc")
      samples.append("sample2d_simplified.cnc")
    if not samples:
      samples.append("sample2d.cnc")
      samples.append("sample2d_simplified.cnc")

  for sample in samples:
    cncPath = os.path.join(dataFolder, sample)
    logPath = os.path.join(jsonFolder, post + ".log")
    ncPath = os.path.join(jsonFolder, post + ".nc")
    try:
      os.remove(ncPath)
    except:
      pass
    arguments = ["post", "--shorten", "50", "--noeditor", "--noheader", "--noprogress", "--quiet", "--time", "--nobackup", "--log", logPath, "--property", "unit", "1", "--property", "programName", "99", "--property", "programComment", "'Automatic test'"]
    arguments.extend([cpsPath, cncPath, ncPath])
    sampleTime = time.time()
    code = subprocess.call(arguments, stdout=null, stderr=subprocess.STDOUT, shell=False)

    sampleTime = time.time() - sampleTime
    if code != 0:
      # print("DEBUG: Failed to post process '%s' with code %d." % (sample, code))
      continue # ignore

    samplePath = ncPath
    if os.path.exists(samplePath):
      filename = os.path.splitext(os.path.basename(cpsPath))[0] + ".nc"
      size = os.path.getsize(samplePath)
      # ATTENION: nested locks are not allowed
      # debug2(post, "Generated sample for program '%s'." % (sample))
      # debug2(post, "Generation size %d" % (size))
      # debug2(post, "Generation time %.3f s" % (sampleTime))
      rate = size * 1.0/sampleTime/1024/1024
      # debug2(post, "Generation performance %.3f Mb/s" % (rate))
      if rate > 1:
        record['performance'] = rate
      record['ncsample'] = filename
      syncFile(samplePath, os.path.join(sampleFolder, filename))
    break # stop on first success

def getOption(data, id):
  for e in data["data"]:
    if e["id"] == "options":
      # print("DEBUG: getOption(): %s = %s" % (id, e["value"]))
      if e["userId"] == id:
        # print("DEBUG: getOption(): %s = %s" % (id, e["value"]))
        return e["value"]
  return None

customPost = None

def convertSimple2CPS(srcPath, destPath):
  config = loadJSON(srcPath)

  global customPost
  if not customPost:
    path = os.path.join(cpsFolder, "custom.cps")
    customPost = readFile(path)

  # print(config)

  description = getOption(config, "description")
  longDescription = getOption(config, "longdescription")
  extension = getOption(config, "extension")

  text = "\n"
  text += "uVpostHeader = " + json.dumps(config, indent=2) + ";\n"
  text += "description = \"%s\";\n" % description
  text += "longDescription = \"%s\";\n" % longDescription
  text += "vendor = \"%s\";\n" % ("Editable")
  text += "vendorUrl = \"%s\";\n" % ("http://www.autodesk.com")
  text += "extension = \"%s\";\n" % (extension)

  data = customPost.replace("// set uVpostHeader here if desired\n", text)
  writeFile(destPath, data)

def writeZipPackage(zipPath, cpsPath, dependencies, change):
  commitId = change.commitID
  postBaseName = os.path.basename(cpsPath)
  with zipfile.ZipFile(zipPath, 'w', zipfile.ZIP_DEFLATED) as zip:
    postData, code, err = readFileFromCommit(commitId, os.path.relpath(cpsPath, cpsFolder))

    if (code != 0):
      writeMessage(f"Could not load post {cpsPath} at commit {commitId}")
      debug(err)
      return code

    # Set revision and date fields in post
    try:
      postData = annotatePost(cpsPath, postData.decode(), change).encode()
    except UnicodeDecodeError:
      # Some commits have encoding errors
      pass
    # Write post to zip
    zip.writestr(postBaseName, postData)

    # Zip up dependencies
    folder = os.path.dirname(cpsPath)
    for dependency in dependencies:
      depData, code, err = readFileFromCommit(commitId, os.path.relpath(os.path.join(folder, dependency), cpsFolder))
      if code == 0:
        zip.writestr(os.path.basename(dependency), depData)
      else:
        writeMessage(f"Could not load dependency {dependency} for post {postBaseName} at {commitId}")
        writeMessage(err.decode())
        return code
    return code

# Process given post.
def processPost(post):
  res = {
    'rssAll' : [],
    'rssVendors' : {},
    'record' : {}
  }
  global hiddenPosts
  global excludedPosts
  global includedPosts

  global machineConnectorNames
  global videoUrls
  global guideUrls
  global redirections

  isDiff = True
  
  simplePath = os.path.join(cpsFolder, post + ".json")
  cpsPath = os.path.join(cpsFolder, post + ".cps")
  destPath = os.path.join(jsonFolder, post + ".json")
  
  postFile = post + ".cps"
  if os.path.isfile(simplePath):
    postFile = post + ".json"

  writeProgress("Processing post '%s'" % postFile)

  try:
    os.remove(destPath)
  except:
    pass

  if not os.path.exists(simplePath):
    simplePath = None # doesnt exist

  editable = False
  if simplePath:
    convertSimple2CPS(simplePath, cpsPath)
    editable = True

  arguments = ["post", "--interrogate", "--noheader", "--noprogress", "--quiet", "--time", "--nobackup", cpsPath, destPath]
  code = subprocess.call(arguments, stdout=null, stderr=subprocess.STDOUT, shell=False)
  if code != 0:
    error2(post, "Failed to post process with code %d." % (code))
    return False

  # get changes for post
  changesPath = os.path.join(changesFolder, os.path.splitext(os.path.basename(cpsPath))[0] + ".json")
  changesLogPath = os.path.join(previousVersionsLogFolder, os.path.splitext(os.path.basename(cpsPath))[0] + ".json")
  allChanges = getChanges(simplePath or cpsPath)
  changes = [change for change in allChanges if len(change.messages) > 0]
  if changes:
    io = StringIO()
    json.dump(changes, io, cls=EncodeEntry)
    isDiff = writeIfDifferent(io.getvalue(), changesLogPath)
  else:
    isDiff = False
    try:
      os.remove(changesLogPath)
    except:
      pass

  # Sync the log file if there is a new entry
  if changes and not os.path.exists(changesPath) or isDiff:
    syncFile(changesLogPath, changesPath)

  record = {}
  with open(destPath) as f:
    bytes = f.read()
  try:
    record = json.loads(bytes)
  except:
    print("Warning[%s]: Failed to load JSON interrogation." % (post))
    # error("Failed to load JSON interrogation.")
    return False
  
  name = os.path.splitext(os.path.basename(cpsPath))[0]
  record['filename'] = name

  record['hidden'] = (name in hiddenPosts)
          
  if changes:
    record['changes'] = True

  debug2(post, "Description:%s Vendor:%s (%s) Forkid:%s" % (record['description'], record['vendor'], record['vendorUrl'], record['forkid']))

  if name in machineConnectorNames:
    record['machineConnectorName'] = machineConnectorNames[name]
    connectorFile = 'machine_connectors/' + machineConnectorNames[name]
    
    extensions = ['.exe', '.zip']
    for extension in extensions:
      connectorFileAndExtension = connectorFile + extension
      connectorSrcPath = os.path.join(cpsFolder, connectorFileAndExtension)
      if os.path.isfile(connectorSrcPath):
        break
    
    if os.path.isfile(connectorSrcPath):
      syncFile(connectorSrcPath, os.path.join(distFolder, connectorFileAndExtension))
      debug2(post, "Machine-connector: %s" % (record['machineConnectorName']))
    else:
      error("Failed to copy machine-connector: %s" % connectorSrcPath)
    
  if name in videoUrls:
    record['video'] = videoUrls[name]
    debug2(post, "Video: %s" % (record['video']))

  if name in guideUrls:
    record['guide'] = guideUrls[name]
    debug2(post, "Guide: %s" % (record['guide']))

  if name in redirections:
    record['redirect'] = redirections[name]
    debug2(post, "Redirection: %s" % (record['redirect']))
	
  if 'capabilities' in record:
    debug2(post, "Capabilities: %s" % (record['capabilities']))

  thumbnailPath = os.path.splitext(cpsPath)[0] + ".png"
  imagePath = os.path.splitext(cpsPath)[0] + "_full.png"

  if 'thumbnail' in record:
    del record['thumbnail']
  if os.path.exists(thumbnailPath):
    filename = os.path.splitext(os.path.basename(cpsPath))[0] + "_thumbnail.png"
    record['thumbnail'] = filename
    syncFile(thumbnailPath, os.path.join(distFolder, filename))
  if 'image' in record:
    del record['image']
  if os.path.exists(imagePath):
    filename = os.path.splitext(os.path.basename(cpsPath))[0] + "_full.png"
    record['image'] = filename
    syncFile(imagePath, os.path.join(distFolder, filename))

  uploadPath = os.path.join(distFolder, os.path.basename(cpsPath))
  changed = not os.path.isfile(uploadPath) or not filecmp.cmp(cpsPath, uploadPath) # TAG: need to handle substitution keywords

  latestChange = allChanges[0]
  if (latestChange == None):
    return False
  
  # record['commitID'] = latestChange.commitID # not used for now
  record['revision'] = latestChange.revision
  record['datetime'] = latestChange.date
  if editable:
    record['editable'] = True

  dependencies = None
  if 'dependencies' in record:
    dependencies = record['dependencies'].split("|")
    if record['dependencies'] and dependencies:
      debug2(post, f"Dependencies: {dependencies}")
      zipPath = os.path.join(distFolder, os.path.splitext(os.path.basename(cpsPath))[0] + ".zip")
      writeZipPackage(zipPath, cpsPath, dependencies, latestChange)
      record['package'] = True
    else:
      record['package'] = False
    del record['dependencies']

  record['hashlog'] = getHashLog(simplePath or cpsPath)

  filename = record['filename']
  if not (filename in hiddenPosts): # RSS feed
    postRSSItems = []
    postFilesForRelease = []

    for entry in changes:
      previousVersionFile = os.path.join(previousVersionsFolder, filename + " r" + str(entry.revision) + ".cps")
      
      # Skip this revision if it is an excluded entry.
      if entry.excluded:
        if os.path.exists(previousVersionFile):
          # Remove the excluded file from the list if it exists already
          os.remove(previousVersionFile)
        continue
      
      if not isDiff:
        continue

      items ={}
      items["revision"] = entry.revision
      items["previousVersionFile"] = previousVersionFile
      items["commitId"] = entry.commitID
      items["package"] = record['package']
      postFilesForRelease.append(items)

      # If previous version already exists, skip
      if os.path.exists(previousVersionFile):
        continue

      # Checkout previous version of post
      code = -1
      if record['package'] and dependencies:
        zipPath = os.path.join(previousVersionsFolder, f"{filename} r{entry.revision}.zip")
        code = writeZipPackage(zipPath, cpsPath, dependencies, entry)
      else :
        code = writeFileFromCommit(entry.commitID, f"{filename}.cps", previousVersionFile, entry)
        if code != 0:
          error2(post, "Failed to post process with code %d." % (code))
          return False

      if code != 0:
        error2('WritePrevVersions', "Failed to git checkout '%s' from %s" % (cpsPath, entry.commitID))
        continue  

    if changes and isDiff:
      changesData = loadJSON(changesPath)
      for post_ in postFilesForRelease:
        # unzip if it is package file to process the post
        if post_["package"]:
          unZipfile(post_["previousVersionFile"], filename)

        # Apped minimum revison to the log file
        addMinimumRevision(post_, changesData)

      # Remove unwanted entries in the log file 
      finalData_ = getFinalPosts(changesData, filename)
      writeFile(changesPath, json.dumps(finalData_))

    for entry in changes:
      # Fetch datetime from change. Stored datetime is UTC.
      dt = datetime.datetime.strptime(entry.date, "%Y-%m-%d %H:%M:%S").replace(tzinfo=datetime.timezone.utc)
      delta = now - dt
      seconds = delta.days * 24*60*60 + delta.seconds
      
      if seconds > 7*24*60*60: # week
        continue

      link = "https://cam.autodesk.com/posts/?p=%s" % (filename.replace(" ", "_"))
      rssItem = (entry.revision, record['description'], filename, entry.messages, link, dt) # revision, description, name, type, message, link, time
      res['rssAll'].append(rssItem)
      postRSSItems.append(rssItem)
      if 'vendor' in record:
        vendor = record['vendor']
        if not vendor in res['rssVendors']:
          res['rssVendors'][vendor] = []
        res['rssVendors'][vendor].append(rssItem)

    # RSS feed for single post
    rssPath = os.path.join(rssFolder, filename + ".rss")
    writeIfDifferent(makeRSS(postRSSItems, filename), rssPath)

  processSamples(record, post, cpsPath)

  if simplePath:
    uploadSimplePath = os.path.join(distFolder, os.path.basename(simplePath))
    syncFile(simplePath, uploadSimplePath)

  newData = readFile(cpsPath)
  newData = annotatePost(cpsPath, newData, latestChange)
  writeIfDifferent(newData, uploadPath)

  res['record'] = record
  return res

def addMinimumRevision(post_, changesData):
  for i in changesData:
    if i["revision"] == post_["revision"]:
      previousVersionJson = os.path.join(str(post_["previousVersionFile"]).split(".cps")[0] + ".json")
      arguments = ["post", "--interrogate", "--noheader", "--noprogress", "--quiet", "--time", "--nobackup", post_["previousVersionFile"], previousVersionJson]
      code = subprocess.call(arguments, stdout=null, stderr=subprocess.STDOUT, shell=False)
      if code != 0:
        error2(post_, "Failed to post process with code %d." % (code))
        return False
      
      with open(previousVersionJson) as f:
        bytes = f.read()
      try:
        previousRecord = json.loads(bytes)
      except:
        print("Warning[%s]: Failed to load JSON interrogation." % (post_["previousVersionFile"]))
        # error("Failed to load JSON interrogation.")
        return False
      
      i["minimumRevision"] = previousRecord["minimumRevision"]
      os.remove(previousVersionJson)
      # Remove the extracted file 
      if post_["package"]:
        os.remove(post_["previousVersionFile"])
      
      #Done for this post
      return

POST_COUNT_MAX = 23
POST_COUNT_MIN = 20
MIN_REV_COUNT = 3
def getFinalPosts(changesData, filename):
  # Filter the files for previous revision
  minRev = []
  finalData = []
  count = 0
  for chg in changesData:
    preVersionFile = os.path.join(previousVersionsFolder, filename + " r" + str(chg["revision"]) + ".cps")
    if count <= POST_COUNT_MAX:
      if "minimumRevision" not in chg:
        count +=1
        finalData.append(chg)
        continue

      minimumRev = chg["minimumRevision"]
      if count >= POST_COUNT_MIN and (len(minRev) > MIN_REV_COUNT or (minimumRev in minRev)):
        if os.path.exists(preVersionFile):
          os.remove(preVersionFile)
        continue
      
      finalData.append(chg)
      if minimumRev not in minRev:
        minRev.append(minimumRev)
    else:
      if os.path.exists(preVersionFile):
        os.remove(preVersionFile)
    count +=1
  return finalData


def annotatePost(cpsPath, postData, change):
  if not (("$Revision$" in postData) and ("$Date$" in postData)):
    debug2(os.path.basename(cpsPath), f"Substitution keywords missing in file {cpsPath}.")
  postData = postData.replace("$Commit$", f"$Commit: {change.commitID} $")
  postData = postData.replace("$Revision$", f"$Revision: {change.revision} {change.commitID} $")
  postData = postData.replace("$Date$", f"$Date: {change.date} $") # TAG: need to use proper format

  return postData

def flatten(source):
  res = {}
  for sub in source:
    for k in sub.keys():
      if not k in res:
        res[k] = sub[k]
      else:
        if isinstance(res[k], dict):
          res[k] = flatten([res[k], sub[k]])
        else:
          res[k] += sub[k]
  return res
  
# Worker for post process.
def worker(tasks):
  res = {
    'failures' : [],
    'records' : [],
    'rssAll' : [],
    'rssVendors' : {}
  }
  for post in tasks:
    result = processPost(post)
    if isinstance(result, bool):
      debug2(post, "Failed to process post.")
      res['failures'].append(post)
      continue
    res['records'].append(result['record'])
    res['rssAll'] += result['rssAll']
    res['rssVendors'] = flatten([res['rssVendors'], result['rssVendors']])
  return res
  
def readLibraryPostDefinitions():
  includeListPath = os.path.join(cpsFolder, "library_posts.txt")
  with open(includeListPath, "r") as f:
    for line in f:
      line = line.split("#")[0]
      line = line.strip()
      if line:
        words = line.split(";")
        if len(words) < 1:
          continue # nothing to parse
        name = words[0]

        exclude = False
        hidden = False
      
        if name.startswith("-"):
          name = name[1:]
          exclude = True
        elif name.startswith("*"):
          name = name[1:]
          hidden = True

        if name == "RETURN":
          print("Return from library.")
          break
        for entry in words[1:]:
          keyvalue = entry.split("=")
          if len(keyvalue) != 2:
            error("Invalid key-value '%s' pair at line '%s'." % (entry, line))
          key = keyvalue[0]
          value = keyvalue[1]
          if not key or not value:
            error("Invalid key-value '%s' pair at line '%s'." % (entry, line))
          elif key == "MACHINE_CONNECTOR":
            if name in machineConnectorNames:
              error("Only a single machine-connector is allowed for line '%s'." % (line))
            machineConnectorNames[name] = value
          elif key == "VIDEO":
            if name in videoUrls:
              error("Only a single video is allowed for line '%s'." % (line))
            videoUrls[name] = value
          elif key == "GUIDE":
            if name in guideUrls:
              error("Only a single guide is allowed for line '%s'." % (line))
            guideUrls[name] = value
          elif key == "REDIRECT":
            if name in redirections:
              error("Only a single redirect is allowed for line '%s'." % (line))
            redirections[name] = value
          elif key == "EXCLUDED_REVISIONS":
            global excludedRevisions
            if name in excludedRevisions:
              error("Only a single array of excluded versions is allowed for line '%s'." % (line))
            excludedRevisions[name] = [int(number) for number in value.split(',')] # Value should be of the form "int,int,..."
          else:
            print("Warning: Unsupported key ignored for '%s'." % line)
        if exclude:
          excludedPosts.append(name)
        else:
          includedPosts.append(name)
          if hidden:
            hiddenPosts.append(name)

def readPostsFromFolder(folder):
  res = []
  for filename in os.listdir(folder):
    if filename.endswith(".cps"):
      res.append(filename)
  return res

def isPostNameValid(name):
  return all(c in approvedCharsForPostName for c in name)
      
def readSourcePosts():
  res = set([])
  invalid = set([])
  for filename in os.listdir(cpsFolder):
    if filename.endswith(".cps") or filename.endswith(".json"):
      name = os.path.splitext(filename)[0]
      if not name.startswith("."):
        if isPostNameValid(name):
          res.add(name)
        else:
          invalid.add(name)
  if invalid:
    error("Invalid file names: " + str(invalid))
  return res
          
def getTaskBatches(source, batchCount):
  res = []
  for q in range(batchCount):
    res.append([])
  
  i = 0
  for p in source :
    res[i % batchCount].append(p)
    i += 1
  return res

def ensureFolders(folders):
  for f in folders:
    if not os.path.exists(f):
      os.makedirs(f)
  
def initWorker():
  signal.signal(signal.SIGINT, signal.SIG_DFL)
    
# Builds the post library.
def buildLibrary():
  global hiddenPosts
  global excludedPosts
  global includedPosts
  global machineConnectorNames
  global videoUrls
  global guideUrls
  global redirections
  global failures

  ensureFolders([
    jsonFolder,
    cppFolder,
    distFolder,
    changesFolder,
    rssFolder,
    rssVendorsFolder,
    sampleFolder,
    previousVersionsFolder,
    previousVersionsLogFolder,
    machineConnectorFolder])
  
  readLibraryPostDefinitions()
  
  existingPosts = map(
    lambda a: os.path.splitext(a)[0], 
    readPostsFromFolder(distFolder)
  )
  
  allPosts = readSourcePosts()
  
  newPosts = set(allPosts) - set(existingPosts)

  batchCount = os.cpu_count()
  
  taskBatches = getTaskBatches(
    set(allPosts) & set(includedPosts),
    batchCount
  )

  startTime = time.time()

  if __name__ == '__main__':
    intro()
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    p = Pool(processes=batchCount, initializer=initWorker)
    try:
      allResults = flatten(p.map(worker, taskBatches))
      db = sorted(allResults['records'], key=lambda r: r['filename'])
      failures = allResults['failures']
      rssAll = allResults['rssAll']
      rssVendors = allResults['rssVendors']
    except KeyboardInterrupt:
      print("Terminated")
      p.terminate()
      sys.exit(0)
    else:
      p.close()
    p.join()

    # make Slack message
    lastRevision, referencePosts = loadReferenceDb()
    print("Last revision: %s" % lastRevision)
    
    writeSlackMessage(db, referencePosts, lastRevision)
    
    printPostsWithoutSamples(db)

    writePostsJson(db)

    writeWebsiteJson(db)

    writeAllPostsHtml(db)

    writeAllPostsZip(readPostsFromFolder(distFolder))

    writeHiddenPostsHtml(db, hiddenPosts)
    
    writeTimestamp()

    writeRevisionTxt()

    writeWhitelist(db)
    writePostLibraryHeader(db)
    writeVendorData(db)
    
    writeRss(distFolder, "posts.rss", rssAll)
    writeRssVendors(rssVendors)

    printPosts("Posts not declared:", set(allPosts) - set(includedPosts) - set(excludedPosts))
    printPosts("Posts hidden:", hiddenPosts)
    printPosts("Posts missing:", set(includedPosts) - set(allPosts))
    
    printPosts("Posts failed:", failures)

    print("Elapsed total processing time %.1fs" % (time.time() - startTime))
    
    if failures:
      sys.exit(1)

def writeTimestamp():
  writeFile(
    os.path.join(distFolder, "timestamp.txt"), 
    str(datetime.datetime.now(datetime.timezone.utc)))

  
def writeRevisionTxt():
  code, out, err = runGit(["git", "-C", cpsFolder, "log", "-n", "1", "--pretty=format:%H"])
  COMMITID = out
  debug(f"Got exit code {code} git -C {cppFolder} log -n 1")
  
  if code != 0:
    error(f"Failed to get git log -n 1 from '{cpsFolder}'")
    COMMITID = ""

  if COMMITID not in commits:
    error(f"Commit {COMMITID} not found in list.")
    return

  REVISION = commits[COMMITID]

  writeFile(
    os.path.join(distFolder, "revision.txt"),
    COMMITID + "\n" + str(REVISION) + "\n")
  
def writeHiddenPostsHtml(data, hiddenPosts):
  res = "<html>"
  res += "<body>"
  hidden = filter(lambda r: r['hidden'], data)
  for record in hidden:
    if 'description' in record:
      res += "<p><a href='/posts?p=" + record['filename'].replace(" ", "_") + "'>" + record['description'] + "</a></p>\n"
  res += "</body>"
  res += "</html>"
  
  writeFile(os.path.join(distFolder, "hiddenposts.html"), res)
 
def unZipfile(zipPackage, postname):
  package = os.path.splitext(zipPackage)
  postname = postname + ".cps"
  with zipfile.ZipFile((package[0] + ".zip"), "r") as z:
    if postname in z.namelist():
      dirt = os.path.dirname(zipPackage)
      z.extract(postname, dirt)
      os.rename(os.path.join(dirt,postname), zipPackage)

def writeAllPostsZip(posts):
  allPostsZipPath = os.path.join(distFolder, "allposts.zip")
  with zipfile.ZipFile(allPostsZipPath, 'w', zipfile.ZIP_DEFLATED) as zip:
    for post in posts:
      postPath = os.path.join(distFolder, post)
      zip.write(postPath, post)
      
def writeAllPostsHtml(data):
  res = "<html>"
  res += "<body>"
  for record in data:
    if not record['filename'] in hiddenPosts: # do not expose post
      if 'description' in record:
        res += "<p><a href='/posts?p=" + record['filename'].replace(" ", "_") + "'>" + record['description'] + "</a></p>\n"
  res += "</body>"
  res += "</html>"
  
  writeFile(os.path.join(distFolder, "allposts.html"), res)
  
def writePostsJson(data):
  io = StringIO()
  import copy
  db2 = copy.deepcopy(data)
  for record in db2: # remove data that isnt used for now
    if 'legal' in record:
      del record['legal']
  json.dump(db2, io)
  dbPath = os.path.join(distFolder, "posts.json")
  writeFile(dbPath, io.getvalue(), "w")

def writeWebsiteJson(data):
  websiteKeys = ('filename', 'vendor', 'description', 'extension', 'revision', 'datetime', 
                  'capabilities', 'hidden', 'thumbnail', 'pdfsample', 'ncsample', 'guide', 
                  'editable', 'model', 'vendorUrl', 'longDescription', 'changes', 'video', 
                  'redirect', 'deprecatedDescription', 'machineConnectorName', 'minimumRevision')
  websiteData = []
  for record in data:
    websiteData.append({k: record[k] for k in websiteKeys if k in record})
  io = StringIO()
  json.dump(websiteData, io)
  dbPath = os.path.join(distFolder, "posts-website.json")
  writeFile(dbPath, io.getvalue(), "w")
  
def printPostsWithoutSamples(data):
  recordsNoSamples = filter(
    lambda d: (not 'pdfsample' in d and not 'ncsample' in d),
    data
  )
  printPosts(
    "Posts without samples:",
    map(lambda d: d['filename'], recordsNoSamples)
  )
  
def writeSlackMessage(data, referencePosts, lastRevision):
  slackPath = os.path.join(rootFolder, "slack.txt")
  
  latestPath = os.path.join(distFolder, "latest.txt") # must be persisted

  updatedPosts = []
  for record in data:
    if not 'description' in record:
      continue
    if record['revision'] <= lastRevision:
      continue      
    updatedPosts.append((record['revision'], record))
  message = ""
  gotPost = False
  if updatedPosts:
    updatedPosts = sorted(updatedPosts, key=lambda p: p[0], reverse=True)
    EOL = "\n"
    message += "Updated post library:" + EOL
    for revision, record in updatedPosts[0:30]:
      gotPost = True
      # TAG: include ticket number if any
      newPost = not record['filename'] in referencePosts
      hidden = record['filename'] in hiddenPosts
      message += "<https://cam.autodesk.com/posts/?p=%s|%s> v%s %s%s" % (
        record['filename'].replace(" ", "_"), 
        record['description'], 
        record['revision'], 
        newPost and ":new:" or "", 
        hidden and ":novision:" or "") + EOL

    writeFile(latestPath, str(updatedPosts[0][0]))

  writeFile(slackPath, message, "w")
  
def writeWhitelist(data):
  # Generate whitelists for collecting user info
  with codecs.open(os.path.join(distFolder, "whitelist.txt"), "w", encoding="utf-8") as f:
    f.write("# FILENAME;VENDOR;DESCRIPTION;CAPABILITIES;REVISION;FORKID;SHA1" + "\n")
    for record in data:
      filename = record['filename']
      
      vendor = ""
      vendorUrl = ""
      if 'vendor' in record:
        vendor = record['vendor']
      if 'vendorUrl' in record:
        vendorUrl = record['vendorUrl']
      
      description = ""
      if 'description' in record:
        description = record['description']
      capabilities = ""
      if 'capabilities' in record:
        capabilities = record['capabilities']
      revision = ""
      if 'revision' in record:
        revision = str(record['revision'])
      forkid = ""
      if 'forkid' in record:
        forkid = str(record['forkid'])
      uploadPath = os.path.join(distFolder, filename + ".cps")
      sha1 = digestFile(uploadPath, "sha1")
      f.write(filename + ";" + vendor + ";" + description + ";" + capabilities + ";" + revision + ";" + forkid + ";" + sha1 + "\n")
  
def writePostLibraryHeader(data):
  with codecs.open(os.path.join(cppFolder, "post_library.h"), "w", encoding="utf-8") as cpp: # put in other folder
    # TAG: how should we handle unicode chars for C++ is UTF-8 ok to use
    cpp.write("// Generated list of posts from post library. Do NOT edit.\n")
    cpp.write("\n")
    cpp.write("/** Entry for the post whitelist. */\n")
    cpp.write("struct PostEntry {\n")
    cpp.write("  const char* description;\n")
    cpp.write("  const char* vendor;\n")
    cpp.write("  const char* vendorUrl;\n")
    cpp.write("  const char* capabilities;\n")
    cpp.write("  const char* forkid;\n")
    cpp.write("};\n")
    cpp.write("\n")
    cpp.write("/** The post whitelist. */\n")
    cpp.write("static const PostEntry POST_LIST[] = {\n")
    for record in data:
      filename = record['filename']
      description = ""
      if 'description' in record:
        description = record['description']
      if description.startswith("Generic "):
        description = description[8:]
      vendor = ""
      vendorUrl = ""
      if 'vendor' in record:
        vendor = record['vendor']
      if 'vendorUrl' in record:
        vendorUrl = record['vendorUrl']

      capabilities = ""
      if 'capabilities' in record:
        capabilities = record['capabilities']
      revision = ""
      if 'revision' in record:
        revision = str(record['revision'])
      forkid = ""
      if 'forkid' in record:
        forkid = str(record['forkid'])
      uploadPath = os.path.join(distFolder, filename + ".cps")
    
      cppCapabilities = ""
      if 'JET' in capabilities: cppCapabilities += "J"
      if 'INTERMEDIATE' in capabilities: cppCapabilities += "I"
      if 'MILLING' in capabilities: cppCapabilities += "M"
      if 'TURNING' in capabilities: cppCapabilities += "T"
      if 'WIRE' in capabilities: cppCapabilities += "W"
      if 'SETUP_SHEET' in capabilities: cppCapabilities += "S"
    
      cpp.write("  {\"" + description + "\", \"" + vendor + "\", \"" + vendorUrl + "\", \"" + cppCapabilities + "\", \"" + forkid + "\"}," + "\n")
    cpp.write("};\n")
  
def writeVendorData(data):
  vendors = dict(map(lambda r: (r['vendor'],r['vendorUrl']), data))
  vs = sorted(vendors.keys())

  with codecs.open(os.path.join(distFolder, "vendors.txt"), "w", encoding="utf-8") as f:
    for vendor in vs:
      f.write(vendor + "\n")

  with codecs.open(os.path.join(cppFolder, "post_vendors.h"), "w", encoding="utf-8") as cpp:# put in other folder
    cpp.write("// Generated list of posts from post library. Do NOT edit.\n")
    cpp.write("\n")
    cpp.write("/** Entry for the post whitelist. */\n")
    cpp.write("struct PostVendorEntry {\n")
    cpp.write("  const char* vendor;\n")
    cpp.write("  const char* vendorUrl;\n")
    cpp.write("};\n")
    cpp.write("\n")
    cpp.write("/** The post whitelist. */\n")
    cpp.write("static const PostVendorEntry POST_VENDOR_LIST[] = {\n")
    for vendor in vendors:
      vendorUrl = vendors[vendor]
      cpp.write("  {\"" + vendor + "\", \"" + vendorUrl + "\"},\n")
    cpp.write("};\n")
  
def printPosts(header, list):
  if list:
    print("")
    print(header)
    for post in list:
      print("  " + post)
    print("")

def writeRss(folder, name, rssAll):
  writeFile(os.path.join(folder, name), makeRSS(rssAll))

def writeRssVendors(vendorData):
  for vendor in vendorData.keys():
    writeRss(rssVendorsFolder, vendor + ".rss", vendorData[vendor])

buildLibrary()
