# Load JPG images from disk, when `<Pathname>` is passed

The idea is to not open the full image when JPG pathname is passed to `#image` method.

Tested only with thousands of JPG images and using only methods visible in `test.rb`  example on Raspberry PI. Encryption and compression will PROBABLY BREAK THIS.

Where loading in-memory left us at mercy of Ruby GC, this example does not seem to increase memory usage due to JPG images at all.