#!/usr/bin/env python

import os
import sys

from os import close, unlink
from shutil import move
from StringIO import StringIO
from tempfile import mkstemp

try:
    import PIL
except ImportError:
    import Image
else:
    from PIL import Image

from raven import Client

from decode import CodeReadException, get_paper_size, paper_matches, read_code
from geoutils import create_geotiff
from imagemath import imgblobs, open as imageopen


# extracted from decode.main
def process_snapshot(input_file):
    """
    Reads an image from stdin, writes it as a GeoTIFF to stdout.
    """
    (highpass_filename, preblobs_filename, postblob_filename) = generate_filenames()

    input = Image.open(StringIO(input_file.read()))
    input.load()

    blobs = imgblobs(input, highpass_filename, preblobs_filename, postblob_filename)
    highpass = Image.open(highpass_filename)
    highpass.load()

    unlink(highpass_filename)
    unlink(preblobs_filename)
    unlink(postblob_filename)

    # read the QR code from the highpass filtered input, mainly because the
    # dimensions are more appropriate (extremely high resolution scans result
    # in insufficiently solid QR codes due to ink / paper textures)
    (_, _, north, west, south, east, _paper, _orientation, _) = read_code(highpass)

    for (s2p, paper, orientation, blobs_abcde) in paper_matches(blobs):
        print >> sys.stderr, paper, orientation, '--', s2p

        if (_paper, _orientation) != (paper, orientation):
            continue

        print_page_number = None

        (paper_width_pt, paper_height_pt) = get_paper_size(paper, orientation)
        geo_args = (paper_width_pt, paper_height_pt, north, west, south, east)

        (geotiff_bytes, _, _) = create_geotiff(input, s2p.inverse(), *geo_args)

        return geotiff_bytes

    raise Exception('could not process source image')


def generate_filenames():
    (handle, highpass_filename) = mkstemp(prefix='highpass-', suffix='.jpg')
    close(handle)

    (handle, preblobs_filename) = mkstemp(prefix='preblobs-', suffix='.jpg')
    close(handle)

    (handle, postblob_filename) = mkstemp(prefix='postblob-', suffix='.png')
    close(handle)

    return (highpass_filename, preblobs_filename, postblob_filename)


if __name__ == '__main__':
    client = Client()

    try:
        print process_snapshot(sys.stdin)
    except:
        client.captureException()
        raise
