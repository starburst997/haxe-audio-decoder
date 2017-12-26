# haxe-audio-decoder

DEVELOPMENT HAS MOVE TO HERE: https://github.com/notessimo/audio-decoder

Library to provide an interface to decode MP3 / OGG.

WIP but OGG is working

OGG is using [haxe_stb_ogg_sound](https://github.com/motion-twin/haxe_stb_ogg_sound) (Motion Twin fork)

MP3 is using a conversion of JLayer (AS3) that I did back in 2007 for the first version of Notessimo now converted to Haxe.

// Problem with using multiple implementation is that we cannot makes sure of the sample loop point...

// So it's probably better to use a pure haxe implementation...
For MP3 Decoder, use this for Native? https://github.com/SempaiGames/extension-mp3

Another MP3 Decoder, https://github.com/cambiata/nx3/tree/d5679d0f2e50a62f5573e935e3076b81008e7e1a/src/com/codeazur/as3icy/decoder

For OGG Encoder, port this? https://github.com/SteveLillis/.NET-Ogg-Vorbis-Encoder

For MP3 Encoder, port this? https://github.com/kikko/Shine-MP3-Encoder-on-AS3-Alchemy/tree/master/lib/shine
