This repo contains several methods of rendering a 2D table of colors in LOVE2D. I have been exploring this topic to find the best way to render tiles for my falling sand game, [JASG](https://kingtut-10101.itch.io/just-another-sand-game-sequel). 

The simplest way of rendering singular, colored pixels is to use love.graphics.rectangle _(rendering mode: original)_. However, if you need something faster (MUCH faster), you should use FFI to modify the raw data of an ImageData object instead _(rendering mode: ffi-bytedata-plotting)_. Multithreaded rendering has the potential to be faster, but it would require you to put your color data into a ByteData object or a 2D C array so you can pass the color data to the threads every frame by reference instead of by value. This is because Lua values in LOVE2D must be _copied_ to the thread and cannot be passed by reference.

You can switch between rendering modes using the number keys at the top of your keyboard. Some extra modes can be accessed if you hold left shift in combination with the number key.

![image](https://github.com/user-attachments/assets/1a4634e0-dd2e-4b98-a2a1-e80fb9f1044a)
