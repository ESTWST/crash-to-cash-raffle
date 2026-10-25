# Audio Mixer (per-app output routing for macOS)

Pick an output device (MacBook speakers, Arzopa monitor, AirPods, ...) for each app that is playing sound.

Requires macOS 14.2+ and Xcode command line tools (`xcode-select --install`).

    ./build.sh
    open AudioMixer.app

On first route, macOS asks for **System Audio Recording** permission (System Settings > Privacy & Security).

## How it works
Core Audio process taps (`AudioHardwareCreateProcessTap`) capture the chosen process, mute it on its
normal output, and a private aggregate device plays it on the device you selected. The slider is a per-app volume.

## Two Chrome windows
Routing is per *process*, not per window. Windows of one Chrome profile share an audio process, so they
can't be split. Use "Open 2nd Chrome profile" (launches Chrome with a separate `--user-data-dir`),
then route each Chrome instance to a different device. A different browser (Safari/Arc/Firefox) also works.
Quitting the mixer restores normal audio.
