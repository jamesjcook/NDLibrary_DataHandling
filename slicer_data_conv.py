#!/usr/bin/python
# Simpleish convert to nhdr +raw.gz script for slicer.
import sys, getopt, ntpath

def main(argv):
    inputfile = ''
    outputfile = ''
    try:
        opts, args = getopt.getopt(argv,"hi:o:",["ifile=","ofile="])
    except getopt.GetoptError:
        print 'nhdr_create.py -i <inputfile> -o <outputfile>'
        sys.exit(2)
    for opt, arg in opts:
        if opt == '-h':
            print 'test.py -i <inputfile> -o <outputfile>'
            sys.exit()
        elif opt in ("-i", "--ifile"):
            inputfile = arg
        elif opt in ("-o", "--ofile"):
            outputfile = arg
            
    infolder, inname = ntpath.split(inputfile)
    #inname = os.path.splitext(inname)[0]
    d_pos=inname.index('.')
    inname=inname[:d_pos]
    print 'Input file is "', inputfile
    print 'Node Name is "', inname
    print 'Output file is "', outputfile
    loadVolume(inputfile)
    scene = slicer.mrmlScene
    volumes = scene.GetNodesByName(inname)
    vol = volumes.GetItemAsObject(0)
    saveNode(vol,outputfile)
    
if __name__ == "__main__":
    main(sys.argv[1:])


#count=scene.GetNumberOfNodesByClass('vtkMRMLVolumeNode');
#volnode=scene.GetNthNodeB

#charpos=path.find("nii"); # -1 for not found.
