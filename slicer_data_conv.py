#!/usr/bin/python
################################################################################
# Simpleish convert to output type script script for slicer.
# Defaults to load whatever save as nhdr +raw.gz.
#
# Optionaly can specify target output bit-depth, will
# convert data and scale to that range.
#

import sys, getopt, ntpath

def main(argv):
    inputfile = ''
    outputfile = ''
    bitdepth = ''
    try:
        opts, args = getopt.getopt(argv,"b:hi:o:",["bitdepth","ifile=","ofile="])
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
            
    infolder, inname = ntpath.split(inputfile)
    d_pos=inname.index('.')
    inname=inname[:d_pos]
    outfolder, outname = ntpath.split(outputfile)
    d_pos=outname.index('.')
    outname=outname[:d_pos]    
    print 'Input file is "' + inputfile + '"'
    print 'Node Name is "' + inname + '"'
    print 'Output file is "' + outputfile + '"'
    loadVolume(inputfile)
    #scene = slicer.mrmlScene
    #volumes = scene.GetNodesByName(inname)
    #vol = volumes.GetItemAsObject(0)
    # Able to fix image intensity using scale image to right scale, then cast to 16bit.
    #vOut = slicer.modules.volumes.logic().CloneVolumeWithoutImageData(scene,vol,outname)

    import SimpleITK as sitk
    import sitkUtils
    #inputImage = sitkUtils.PullFromSlicer('MRHead')
    #filter = sitk.SignedMaurerDistanceMapImageFilter()
    #outputImage = filter.Execute(inputImage)
    #sitkUtils.PushToSlicer(outputImage,'outputImage')
    from SimpleFilters import SimpleFiltersLogic
    
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
    
    if not bitdepth:
        print "Not changing bitdepth."
    else
        myFilter = sitk.RescaleIntensityImageFilter()
        myFilter.SetDebug(False)
        myFilter.SetNumberOfThreads(8)
        in_im=sitkUtils.PullFromSlicer(inname)
        out_im=myFilter.Execute(in_im,0.0,im_max)
        myFilter = CastImageFilter()
        myFilter.SetDebug(False)
        myFilter.SetNumberOfThreads(8)
        #sitk.sitkUInt16
        #eval('sitk.sitkUInt16')
        bt='sitk.sitk'+bitdepth
        myFilter.SetOutputPixelType(eval(bt))
        out_im=myFilter.Execute(out_im)
        sitkUtils.PushToSlicer(out_im,outname)
        
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

    saveNode(vOut,outputfile)
    
if __name__ == "__main__":
    main(sys.argv[1:])


#count=scene.GetNumberOfNodesByClass('vtkMRMLVolumeNode');
#volnode=scene.GetNthNodeB

#charpos=path.find("nii"); # -1 for not found.

