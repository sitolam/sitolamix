### About Code and Illustrations License

Hi I'm Shige! Since add-ons is open source basically anyone can fork and use it freely, but this customized version of the Leaderboard Add-on has a bit of a complicated license for now.

## Source Code

### Add-on code

The original leaderboard is MIT licensed. However, Anki and Add-ons use PyQt, so they cannot be MIT licensed (pyQt requires code to be published, MIT does not), so this add-on is under the AGPL license. But I don't know if it is technically possible to change the license from MIT to AGPL (I'm not the original author), so it may be MIT license.

### Server code

The server code is separate from Anki, so I think it is possible to make the license MIT, so I am making it MIT. But the server code has not been released yet.  Because I need to exclude passwords and private info in the database, this work is not done yet. The AGPL requires the code to be public, but I think MIT can make it closed source. (Maybe official Anki and Anking have closed-sourced their servers). The basic server mechanism is almost the same as the original leaderboard, so I don't think it is too urgent.

## Illustrations

The illustrations and icons I have added to this leaderboard are made from game assets that I have obtained legally (Commercial use of these materials is also permitted.)

However if you want to reuse them it is a bit difficult. Icons and illustrations are separate from the code license. (The AGPL affects the license of the code, but as far as I know it does not affect the license of the illustrations.) Each illustration has its own license.

So far it's like this:

### Redistributable

1. League icons: Redistributable. CC0 license so you can use it for whatever you want.

2. Green login dot: I drew this dot, you can use it freely.

3. Country icons: You can get the illustration from Github.

### Not for redistribution

1. Pixel art of a tree
2. Illustration of a timer
3. Pixel art of progress bar
4. Weather icons
    * I cannot redistribute these. The original illustrations are available for free, but I edited them with paint software, so you can't get the same ones.

1. Orbs, diamonds, crystals:
    * I cannot redistribute them. Also you can't get these materials newly. These are game assets I got before and I edited them directly in paint software. The artist is no longer active and no longer publishes the assets, so there is no way to get new ones.

#### Why can't re-distribute the illustrations?

In many cases creators prohibit redistribution of their illustrations. Even if free, they often sell them for a fee later, or they advertise with free materials and get illustration jobs. So I cannot redistribute or resell these illustrations.

#### Future plans

So if developers want to use this add-on they need to change the illustrations to your own or exclude them. Basically only the purchaser can use and edit game assets, if the artist is strict the illustrations should be encrypted.

Of course these are very annoying (If a company has the budget it may be relatively easy to hire an artist to do the game assets). If using CC0 licensed illustrations I can redistribute them, but there are not many high quality assets available under CC0.

I think the ideal solution to this problem is to create the code and all resources (illustrations, etc.) under a shareable license from the beginning. (e.g. Rewrite the code entirely and make the license clear. Order custom illustrations from artists and ask for permission to share them freely.)

In short, if I have the copyright then I can freely give permission and these problems do not occur. For now this is not possible due to development costs and budget, but it may be possible in the future. (Because I'm mainly developing add-ons for Gamification of Learning and receiving support from my patrons.)
