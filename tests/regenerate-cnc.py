"""Regenerate cnc script"""
import logging
import os
import subprocess
import time
import traceback

import adsk
from adsk import core, fusion, cam

app = None
ui = None
statusMessage = ""
postlibTestFolder = ""


def run(context):
    """Called via fusion -execute text command.

    Args:
        context: script context
    """
    logging.basicConfig(
        format="%(asctime)s-%(levelname)s-%(module)s-%(funcName)s-%(message)s",
        level=logging.INFO,
    )

    try:
        global app, ui, postlibTestFolder
        app = core.Application.get()
        ui = app.userInterface

        # Expected in post-library/tests
        postlibTestFolder = os.path.dirname(os.path.realpath(__file__))
        logging.debug("Active workspace:", postlibTestFolder)

        regenerate_cnc(True, True)

    except:
        logging.critical(traceback.format_exc())


def regenerate_cnc(runAll, continueOnFail):
    """Regenerate CNC files.

    Args:
        runAll (bool): Regenerate for all parts in post-library/tests, not just the active document.
        continueOnFail (bool): Skip cnc generation for current part if failure occured.
    """
    doc = app.activeDocument

    if not runAll:
        status = _regenerate_model(doc, save=False)

    else:
        partFolder = os.path.join(postlibTestFolder, "Parts")
        importManager = app.importManager

        # Loop through part files
        for file in os.listdir(partFolder):
            if file.endswith(".f3d"):
                modelName = os.path.basename(file)
                filename = os.path.join(partFolder, modelName)
                importOptions = importManager.createFusionArchiveImportOptions(filename)
                importManager.importToNewDocument(importOptions)
                doc = app.activeDocument
                doc.name = os.path.splitext(modelName)[0]
                logging.debug("Current f3d", doc.name, filename)

                status = _regenerate_model(doc, save=True, filename=filename)

                if not status and continueOnFail:
                    continue
                elif not status and not continueOnFail:
                    return

    logging.info("Finished regenerating cnc files.")

    return


def _generateToolPaths(doc):
    products = doc.products
    product = products.itemByProductType("CAMProductType")
    cam = adsk.cam.CAM.cast(product)

    if not cam.setups.count:
        logging.error(
            "There are no CAM operations in the active document.  This script requires the active document to contain at least one CAM operation."
        )
        return False

    # TAG: Additive toolpaths must first be deleted before being regenerated
    hasAdditive = False
    count = 0
    setupLength = cam.setups.count
    while count < setupLength:
        setup = cam.setups.item(count)
        if isAdditive(setup):
            cam.clearToolpath(setup)
            hasAdditive = True
        count += 1

    # TAG: Additive toolpaths have to be created per setup, not all at once
    if hasAdditive:
        count = 0
        while count < setupLength:
            setup = cam.setups.item(count)
            cam.generateToolpath(setup)
            # count += 1

            # TAG: isGenerationCompleted does not work with Additive toolpaths
            # time.sleep(1.5)
            # if isAdditive(setup):
            operations = setup.allOperations
            opcount = 0
            while opcount < operations.count:
                safetyCount = 0
                while safetyCount < 10:
                    if operations.item(opcount).isToolpathValid:
                        break
                    time.sleep(0.5)
                    safetyCount += 1
                opcount += 1
            count += 1
    else:
        # generate all toolpaths
        future = cam.generateAllToolpaths(False)

        numOps = future.numberOfOperations

        # create and show the progress dialog while the toolpaths are being generated.
        progress = ui.createProgressDialog()
        progress.isCancelButtonShown = False
        progress.show("Toolpath Generation Progress", "Generating Toolpaths", 0, 10)

        # Loop while toolpaths are generated and display progress
        while not future.isGenerationCompleted:
            # since toolpaths are calculated in parallel, loop the progress bar while the toolpaths
            # are being generated but none are yet complete.
            n = 0
            start = time.time()
            # while future.numberOfCompleted == 0:
            # if time.time() - start > .125: # increment the progess value every .125 seconds.
            # start = time.time()
            # n +=1
            # progress.progressValue = n
            # adsk.doEvents()
            # if n > 10:
            # n = 0
            # The first toolpath has finished computing so now display better
            # information in the progress dialog.
            # set the progress bar value to the number of completed toolpaths
            progress.progressValue = future.numberOfCompleted

            # set the progress bar max to the number of operations to be completed.
            progress.maximumValue = numOps

            # set the message for the progress dialog to track the progress value and the total number of operations to be completed.
            progress.message = "Generating %v of %m" + " Toolpaths"
            adsk.doEvents()

        progress.hide()

    # Verify a toolpath has been generated for all operations
    count = 0
    setupLength = cam.setups.count
    while count < setupLength:
        setup = cam.setups.item(count)
        operations = setup.allOperations
        opcount = 0
        while opcount < operations.count:
            if not operations.item(opcount).hasToolpath:
                logging.error(
                    "ERROR: Could not generate tool path for ."
                    + operations.item(opcount).name
                )
                return False
            opcount += 1
        count += 1

    return True


def _createCNCFiles(doc, modelName):
    global statusMessage
    try:
        products = doc.products
        product = products.itemByProductType("CAMProductType")
        cam = adsk.cam.CAM.cast(product)

        # get folder to output CNC file to
        outputFolder = cam.temporaryFolder
        postFolder = os.path.join(postlibTestFolder, "Posts")

        postConfig = os.path.join(postFolder, "export cnc file to qatest.cps")

        # define output CNC folder
        cncExtension = ".cnc"
        cncPath = os.path.join(postlibTestFolder, "cnc")

        # specify the NC file output units
        units = adsk.cam.PostOutputUnitOptions.DocumentUnitsOutput

        # Get the setup count
        count = 0
        setupLength = int(cam.setups.count)

        # Get count of folders & create list of folders/patterns to process
        numOps = 0
        folderArray = core.ObjectCollection.create()
        while count < setupLength:
            setup = cam.setups.item(count)
            if isAdditive(setup):
                numOps += 1
            else:
                folder = setup.folders
                pattern = setup.patterns
                numOps += folder.count + pattern.count
                ops = 0
                while ops < folder.count:
                    folderArray.add(folder[ops])
                    ops += 1
                ops = 0
                while ops < pattern.count:
                    folderArray.add(pattern[ops])
                    ops += 1
            count = int(count + 1)
        totalCount = 0

        if numOps == 0:
            logging.error(
                "ERROR: There are no CAM operations in the active document.  This script requires the active document to contain at least one CAM operation."
            )
            return False

        #  create and show the progress dialog while the CNC files are being generated.
        progress = ui.createProgressDialog()
        progress.isCancelButtonShown = False
        progress.show("Generating CNC Files Progress", "Generating CNC Files", 0, 10)

        EOL = "<br>"
        TAB = "&nbsp;&nbsp;"
        statusMessage = EOL + EOL
        statusMessage = statusMessage + "<b>CNC files created for " + modelName + "</b>"
        count = 0
        while count < setupLength:
            setup = cam.setups.item(count)
            if isAdditive(setup):
                folderLength = 1
            else:
                folder = folderArray  # setup.folders
                folderLength = int(folder.count)
            folderCount = 0

            # Get CNC type from 'Setup: type'
            text = setup.name.split(":")
            if len(text) != 2:
                progress.hide()
                logging.error(
                    'ERROR: Setup name "'
                    + setup.name
                    + '" must be in the format "Name: type"'
                )
                return False
            setupName = text[0].strip()
            machineConfig = text[1].lower().strip()
            if (
                machineConfig != "milling"
                and machineConfig != "turning"
                and machineConfig != "jet"
                and machineConfig != "millturn"
                and machineConfig != "milljet"
                and machineConfig != "generic"
                and machineConfig != "additive"
            ):
                progress.hide()
                logging.error(
                    "ERROR: Invalid CNC file type: " + machineConfig,
                    "Invalid CNC File Type",
                )
                return False
            cncType = "#" + machineConfig + "#"

            statusMessage = statusMessage + EOL + setup.name
            while folderCount < folderLength:
                programName = cncType
                if isAdditive(setup):
                    name = setupName
                else:
                    name = folder.item(folderCount).name
                statusMessage = statusMessage + EOL + TAB + TAB + name

                # set the progress bar value to the number of completed toolpaths
                progress.progressValue = totalCount
                totalCount += 1

                # set the progress bar max to the number of operations to be completed.
                progress.maximumValue = numOps

                # set the message for the progress dialog to track the progress value and the total number of operations to be completed.
                progress.message = name
                adsk.doEvents()

                # create the postInput object
                postInput = adsk.cam.PostProcessInput.create(
                    programName, postConfig, outputFolder, units
                )
                postInput.isOpenInEditor = False

                # remove existing file
                cncFile = os.path.join(cncPath, machineConfig, name + cncExtension)
                if os.path.exists(cncFile):
                    os.remove(cncFile)

                # export the CNC file
                if (
                    folderLength == 1
                ):  # Additive does not support folders or Setup could create multiple WCS copies
                    status = cam.postProcess(setup, postInput)
                else:
                    status = cam.postProcess(folder.item(folderCount), postInput)
                if status != True:
                    logging.error(
                        "ERROR: Failed to post process " + name,
                        "Failed to Post Process",
                    )
                    return False

                # wait for CNC file to be generated
                # time.sleep(1)
                times = 0
                exists = False
                while exists != True and times < 10:
                    if os.path.exists(cncFile):
                        exists = True
                        break
                    times += 1
                    time.sleep(0.5)
                if exists != True:
                    logging.error("ERROR: Could not generate CNC file\n" + cncFile)
                    return False
                folderCount = int(folderCount + 1)

            count = int(count + 1)

        progress.hide()
        return True

    except:
        logging.critical(traceback.format_exc())
        return False


def stop(context):
    try:
        app = core.Application.get()
        ui = app.userInterface
    except:
        logging.critical(traceback.format_exc())


def check_master_br(ui):
    branch = subprocess.check_output(
        "cmd /A /S /C cd " + postlibTestFolder + ' && "git" symbolic-ref --short HEAD',
        shell=False,
        stderr=subprocess.STDOUT,
    )
    if "master" in str(branch):
        logging.error(
            "ERROR: You cannot recreate the production CNC files in the master branch"
        )
        return


def isAdditive(setup):
    global app, ui, statusMessage, postlibTestFolder

    # Get CNC type from 'Setup: type'
    text = setup.name.split(":")
    if len(text) != 2:
        return False
    else:
        machineConfig = text[1].lower().strip()
        if machineConfig == "additive":
            return True
        return False


def _regenerate_model(doc, save=False, filename=None):
    status = _generateToolPaths(doc)
    if not status:
        logging.error(
            "Failed to generate toolpaths for part",
            doc.name,
            stack_info=True,
        )
        return status

    # Create production CNC files from regenerated tool paths
    status = _createCNCFiles(doc, doc.name)
    if not status:
        logging.error(
            "Failed to regenerate CNC files for part",
            doc.name,
            stack_info=True,
        )
        return status

    if save and filename is not None:
        status = _exportUpdatedPart(doc, filename)
        if not status:
            logging.error(
                "Failed to save updated part",
                doc.name,
                stack_info=True,
            )

    return status


def _exportUpdatedPart(doc, filename):
    products = doc.products
    product = products.itemByProductType("DesignProductType")
    design = fusion.Design.cast(product)
    exportManager = fusion.ExportManager.cast(design.exportManager)

    exportOptions = exportManager.createFusionArchiveExportOptions(filename)
    status = exportManager.execute(exportOptions)

    if not status:
        logging.error("Failed to save " + filename + ".", "Cannot Save Model")

    return status


def _showErr(msg=None, title=None):
    if ui:
        if msg is None:
            ui.messageBox("Failed:\n{}".format(traceback.format_exc()))
        else:
            ui.messageBox(
                "ERROR: " + msg,
                title,
                core.MessageBoxButtonTypes.OKButtonType,
                core.MessageBoxIconTypes.CriticalIconType,
            )


if __name__ == "__main__":
    run(None)
