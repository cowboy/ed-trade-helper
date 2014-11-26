# the big idea

User:

1. take screenshots of the commodities screen
1. scroll down a little
1. repeat previos steps until there's nothing left to scroll

Script:

1. crop out scrolling area
1. post process to improve stitching reliability?
1. stitch images together into one big list
1. post process to improve ocr?
1. use ocr to scan image
1. convert to tabular form
1. update a spreadsheet

Todo:

1. detect image station / system?

Ultimately the script should watch the screenshots directory, and when a new screenshot is detected:

1. crop the image
1. if a continuation, join the screenshot to a previous joined image
 * once a join is complete (can we detect this?) ocr the data and update a spreadsheet
1. if not a continuation, start a new joined screenshot
