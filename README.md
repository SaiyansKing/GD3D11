# GD3D11 (Gothic Direct3D 11) Renderer [![GitHub Actions](https://github.com/SaiyansKing/GD3D11/actions/workflows/build.yml/badge.svg)](https://github.com/SaiyansKing/GD3D11/actions) [![GitHub release (latest by date including pre-releases)](https://img.shields.io/github/v/release/SaiyansKing/GD3D11?include_prereleases)](https://github.com/SaiyansKing/GD3D11/releases)

This mod for the games **Gothic** and **Gothic II** brings the engine of those games into a more modern state. Through a custom implementation of the DirectDraw-API and using hooking and assembler-code-modifications of Gothic's internal engine calls, this mod completely replaces Gothic's old rendering architecture.

The new renderer is able to utilize more of the current GPU generation's power. Since Gothic's engine in its original state tries to cull as much as possible, this takes a lot of work from the CPU, which was slowing down the game even on today's processors. While the original renderer did a really great job with the tech from 2002, GPUs have grown much faster. And now, that they can actually use their power to render, we not only get a big performance boost on most systems, but also more features:

* Dynamic Shadows
* Increased draw distance
* Increased Performance
* HBAO+
* Water refractions
* Atmospheric Scattering
* Heightfog
* Normalmapping
* Full DynamicLighting
* Vegetationgeneration
* Hardware Tessellation
* Editor-Panel to insert some of the renderers features into the world
* Custom-Built UI-Framework based on Direct2D
* Rewritten bink player for better compatibility with bink videos
* FPS-Limiter

## Installation & Usage
> **Note**: In the past there used to be separate files for Gothic 1 and Gothic 2, this has now changed since the mod will automatically detect the game.
1. Download the **GD3D11-*LATEST_VERSION*-ci.zip** file from the **Assets** section in the latest release of this repository (e.g. [SaiyansKing/releases](https://github.com/SaiyansKing/GD3D11/releases/latest)).
3. Unpack the zip file and copy the content into the `Gothic\system\` or `Gothic2\system\` game folder.
4. When starting the game you should see the version number of GD3D11 in the top-left corner.
5. As soon as you start the game for the first time after the installation you should press F11 to open the renderer menu and press `Apply(*)`. This saves all the options to `Gothic(2)\system\GD3D11\UserSettings.ini`.

## Bugs & Problems

If you have problems with building GD3D11 after following these instructions or experience bugs/problems with GD3D11 itself, open an issue on this GitHub page or post in the D3D11 thread on ["World of Gothic" (WOG)](http://forum.worldofplayers.de/forum/forums/104-Editing).  
But first take a look at the [KNOWN ISSUES](./known_issues.md)

## Building

### Latest version

Building the mod is currently only possible with windows, but should be easy to do for anyone. To build the mod, you need to do the following:

- Download & install **Git** (or any Git client) and clone this GitHub repository to get the GD3D11 code.
- Download & install **Microsoft Visual Studio 2019** (Community Edition is fine, make sure to enable C++ Tools during installation!). Might work on 2015 or 2017 but untested.
- ~~Download ... DirectX SDK ...~~ Not dependent on DirectX SDK anymore.
- Optional: Set environment variables "G2_SYSTEM_PATH" and/or "G1_SYSTEM_PATH", which should point to the "system"-folders of the games.

To build GD3D11, open its solution file (.sln) with Visual Studio. It will the load all the required projects. There are multiple build targets, one for release and one for developing / testing, for both games each:

* Gothic 2 Release using AVX: "Release_AVX"
* Gothic 1 Release using AVX: "Release_G1_AVX"
* Gothic 2 Release using old SSE2: "Release"
* Gothic 1 Release using old SSE2: "Release_G1"
* Gothic 2 Develop: "Release_NoOpt"
* Gothic 1 Develop: "Release_NoOpt_G1"

> **Note**: A real "debug" build is not possible, since mixing debug- and release-DLLs is not allowed, but for the Develop targets optimization is turned off, which makes it possible to use the debugger from Visual Studio with the built DLL when using a Develop target.

Select the target for which you want to built (if you don't want to create a release, select one of the Develop targets), then build the solution. When the C++ build has completed successfully, the DLL with the built code and all needed files (pdb, shaders) will be copied into the game directory as you specified with the environment variables.

After that, the game will be automatically started and should now run with the GD3D11 code that you just built.

When using a Develop target, you might get several exceptions during the start of the game. This is normal and you can safely continue to run the game for all of them (press continue, won't work for "real" exceptions of course).
When using a Release target, those same exceptions will very likely stop the execution of the game, which is why you should use Develop targets from Visual Studio and test your release builds by starting Gothic 1/2 directly from the game folder yourself.

### Producing the Redistributables
- Compile all versions (e.g. by running `BuildAll.bat`)
- Run `CreateRedist_All.bat` to create separate zip files containing the required files
> **Note**: On CI this process is different. Release builds will bundle all DLL files (SpacerNET is a seperate build) and the launcher will decide which version should be used at runtime. Therefore there is only one zip file for Gothic 1 and Gothic 2.

### Dependencies

- HBAO+ files from [dboleslawski/VVVV.HBAOPlus](https://github.com/dboleslawski/VVVV.HBAOPlus/tree/master/Dependencies/NVIDIA-HBAOPlus)
- [AntTweakBar](https://sourceforge.net/projects/anttweakbar/)
- [assimp](https://github.com/assimp/assimp)

## Special Thanks

... to the following people

- [@ataulien](https://github.com/ataulien) (Degenerated @ WoG) for creating this project.
- [@BonneCW](https://github.com/BonneCW) (Bonne6 @ WoG) for providing the base for this modified version.
- [@lucifer602288](https://github.com/lucifer602288) (Keks1 @ WoG) for testing, helping with conversions and implementing several features.
- [@SaiyansKing](https://github.com/SaiyansKing) for fixing a lot of issues and adding major features.

<a href="https://github.com/SaiyansKing/GD3D11/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=SaiyansKing/GD3D11" />
</a>

## License

- HBAO+ is licensed under [GameWorks Binary SDK EULA](https://developer.nvidia.com/gameworks-sdk-eula)
