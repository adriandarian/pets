# Nimbus Lightning Length and Cadence Design

## Goal

Make Nimbus lightning easier to see by extending the bolt farther below the cloud and showing the existing double-flash sequence more often. Rain behavior, lightning brightness, pet motion, and animation efficiency remain unchanged.

## Visual Geometry

- Increase the lightning path height from 29 to 42 points while keeping its width at 13 points.
- Keep the bolt's current top edge fixed. Move its center downward by 6.5 points so the additional 13 points extend only below the cloud.
- Apply identical geometry to the SwiftUI Canvas renderer used during reactions and the Core Animation renderer used during steady animation.

## Cadence

- Reduce the double-flash cycle from 4.8 seconds to 3.2 seconds.
- Preserve the existing two-pulse shape, relative pulse brightness, and phase offset between pets.
- Keep lightning disabled when ambient motion is disabled.

## Verification

- Add sampling tests that fail with the 4.8-second cadence and pass when strong flashes repeat 3.2 seconds apart.
- Add renderer source checks that require a 42-point bolt and the downward-adjusted center in both rendering paths.
- Run the full project check, rebuild `dist/Pets.app`, and relaunch through a normal application quit/open flow.
