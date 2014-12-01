# Elite: Dangerous Trade Helper

Watch screenshots directory for Commodities Market images, stitching together same-market images into a single image with the same filename as the station.

## Future goals

* Support other screen resolutions than 1900x1200 (patches welcome!)
* Make OCR work?

## Dependencies

* [Elite: Dangerous](http://www.elitedangerous.com/) (duh)
* [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
* [Vagrant](https://www.vagrantup.com/downloads)
* [GitHub Windows](https://windows.github.com/) or [Git](http://msysgit.github.io/)
* If you plan on editing files, an editor that supports Unix line endings (lf)

## Setup

1. Fork this repo to your GitHub account
  * Create a free GitHub account and click the "fork" button in the top right of this page.
1. Clone your fork
  * In the GitHub Windows client, click the + in the top right and clone ed-trade-helper.
1. Open in Git Shell
  * In the GitHub Windows client, right-click ed-trade-helper on the left, Open in Git Shell.
1. Initialize vagrant
  * Type `vagrant up`.
  * You should see mostly green with some red text, and at the end it should say "PLAY RECAP" followed by "ok=5 changed=3 unreachable=0 failed=0"
  * If there are failures, you can `vagrant destroy -f` and then `vagrant up` again.

(Or if you know Git, you can do the first few steps however you'd like)

## Usage

Start the script with `vagrant ssh -c /vagrant/process/process.sh`. Specify options like `vagrant ssh -c "/vagrant/process/process.sh -option"`.

* Pre-existing screenshots are ignored unless the `-f` option is used.
* The script will wait in a loop for new images to be added unless the `-o` option is used.
* New screenshots will be processed, in-order.
* Stitched images will be saved in the `output` subdirectory of the cloned repository.

## Commodities Market Screenshot Instructions

* Don't take screenshots while the ship is moving.
* The left panel should NOT be highlighted while taking a screenshot. Hover over the right "item details" panel to de-highlight the left panel. If you place the mouse cursor just to the left of the scroll bar, it will scroll the market without highlighting it.
* The first screenshot should be taken while the market is scrolled all the way to the top.
* Subsequent screenshots should be scrolled down no more than 4 ticks on the mousewheel. If there is no overlap between screenshots, stitching will fail.
* After 1 minute, the last market screenshot is invalidated, so don't take longer than 1 minute between screenshots for the same market.
* If the OCR incorrectly matches the station name, add a correction in the format `BADWORD GOODWORD` to the [reference/ocr_fixes.txt](reference/ocr_fixes.txt) (ensure the file has a trailing newline) file and try again.
