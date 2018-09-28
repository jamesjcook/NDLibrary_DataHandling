#!/usr/bin/python
################################################################################
# Simpleish convert to output type script script for slicer.
# Defaults to load whatever save as nhdr +raw.gz.
#
# Optionaly can specify target output bit-depth, will
# convert data and scale to that range.
#

import sys, getopt, ntpath
import SimpleITK as sitk
import sitkUtils

def main(argv):
    inputfile = ''
    outputfile = ''
    bitdepth = ''
    try:
        opts, args = getopt.getopt(argv,"b:hi:o:",["bitdepth=","ifile=","ofile="])
    except getopt.GetoptError:
        print 'nhdr_create.py -i <inputfile> -o <outputfile> [-bitdpeth <sitkbitdepths>]'
        print 'see https://itk.org/SimpleITKDoxygen/html/namespaceitk_1_1simple.html#ae40bd64640f4014fba1a8a872ab4df98 for the bitdepth info'
        sys.exit(2)
    for opt, arg in opts:
        if opt == '-h':
            print 'test.py -i <inputfile> -o <outputfile>'
            sys.exit()
        elif opt in ("-i", "--ifile"):
            inputfile = arg
        elif opt in ("-o", "--ofile"):
            outputfile = arg
        elif opt in ("-b", "--bitdepth"):
            bitdepth = arg
            print 'bitdepth found"' + bitdepth + '"'
            
    infolder, inname = ntpath.split(inputfile)
    d_pos=inname.index('.')
    inname=inname[:d_pos]
    outfolder, outname = ntpath.split(outputfile)
    d_pos=outname.index('.')
    outname=outname[:d_pos]    
    print 'Input file is "' + inputfile + '"'
    print 'Node Name is "' + inname + '"'
    print 'Output file is "' + outputfile + '"'
    if bitdepth:
        print 'Changing bitdepth output to "' + bitdepth + '"'
        
    loadVolume(inputfile)
    scene = slicer.mrmlScene
    volumes = scene.GetNodesByName(inname)
    vol = volumes.GetItemAsObject(volumes.GetNumberOfItems()-1)
    vol.SetName(inname+'in')
    inname=inname+'in'
    outname=outname+'_out'
    #vol = volumes.GetItemAsObject(0)
    # Able to fix image intensity using scale image to right scale, then cast to 16bit.
    #vOut = slicer.modules.volumes.logic().CloneVolumeWithoutImageData(scene,vol,outname)

    #inputImage = sitkUtils.PullFromSlicer('MRHead')
    #filter = sitk.SignedMaurerDistanceMapImageFilter()
    #outputImage = filter.Execute(inputImage)
    #sitkUtils.PushToSlicer(outputImage,'outputImage')
    #from SimpleFilters import SimpleFiltersLogic
    
    #filter = SimpleFiltersLogic()
    #myFilter = sitk.RescaleIntensityImageFilter()
    #myFilter.SetDebug(False)
    #myFilter.SetNumberOfThreads(8)
    #myFilter.SetOutputMinimum(0.0)
    #myFilter.SetOutputMaximum(65535.0)
    #filter.run(myFilter, vOut, False, slicer.util.getNode(inname))
    #filter.main_queue_running
    #while filter.main_queue_running:
    #    sleep(0.5)
    scene = slicer.mrmlScene    
    if not bitdepth:
        print "Not changing bitdepth."
        print "Getting vol from scene for save"
        volumes = scene.GetNodesByName(inname)
    else:
        print "Setting IM Max by bitdepth"
        if bitdepth == "UInt64":
            im_max=4294967296
        elif bitdepth == "UInt32":
            im_max=4294967296
        elif bitdepth == "UInt16":
            im_max=65535
        elif bitdepth == "UInt8":
            im_max=255
        elif bitdepth == "Int64":
            im_max=2147483647
        elif bitdepth == "Int32":
            im_max=2147483647
        elif bitdepth == "Int16":
            im_max=32767
        elif bitdepth == "Int8":
            im_max=128
        elif bitdepth == "LabelUInt64":
            im_max=4294967296
        elif bitdepth == "LabelUInt32":
            im_max=4294967296
        elif bitdepth == "LabelUInt16":
            im_max=65535
        elif bitdepth == "LabelUInt8":
            im_max=255
        else:
            raise NameError('UnsupportedBitDepthSpecified')
            
        print "Setting up rescale filter"
        myFilter = sitk.RescaleIntensityImageFilter()
        myFilter.SetDebug(False)
        myFilter.SetNumberOfThreads(8)
        # deprecated
        #in_im=sitkUtils.PullFromSlicer(inname)
        in_im=sitkUtils.PullVolumeFromSlicer(inname)
        
        print "execute rescale"
        out_im=myFilter.Execute(in_im,0.0,im_max)
        print "Setting up cast filter"
        myFilter = sitk.CastImageFilter()
        myFilter.SetDebug(False)
        myFilter.SetNumberOfThreads(8)
        #sitk.sitkUInt16
        #eval('sitk.sitkUInt16')
        bt='sitk.sitk'+bitdepth
        print "Using bitdepth code " + bt + "(" +  str(eval(bt)) + ")"
        myFilter.SetOutputPixelType(eval(bt))
        print "execute cast"
        out_im=myFilter.Execute(out_im)
        sitkUtils.PushToSlicer(out_im,outname)
        print "Getting vol from scene for save"
        volumes = scene.GetNodesByName(outname)
        
    #####
    # example code
    #histoMap =
    #slicer.modules.volumes.logic().CreateAndAddLabelVolume(self.histoVolumeBW,
    #                                                       'Histo_Final_Label_Map')
    #from SimpleFilters import SimpleFiltersLogic
    #filter = SimpleFiltersLogic()
    # subtractimagefilter has params, input input out.
    #filter.run(sitk.SubtractImageFilter(), histoMap, True,
    #           slicer.util.getNode('Histo_Label_Map'),
    #           slicer.util.getNode('Histo_Urethra_Label_Map'))
    #####
    vOut = volumes.GetItemAsObject(volumes.GetNumberOfItems()-1)
    print "saving node " + outname
    saveNode(vOut,outputfile)
    
if __name__ == "__main__":
    main(sys.argv[1:])


#count=scene.GetNumberOfNodesByClass('vtkMRMLVolumeNode');
#volnode=scene.GetNthNodeB

#charpos=path.find("nii"); # -1 for not found.

