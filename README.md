# EuropaClipper_JUICE_UVS

**Status: archived.** Observation-planning work from my planetary-science instrument period, active 2022-2023 and unchanged since September 2023. Kept public as work history; not maintained.

## What it is

An IDL tool that simulates what the Europa Clipper UVS ultraviolet spectrograph detector would record during a candidate observation. Given a time range, an exposure count, a SPICE metakernel, and a target moon (Europa, Ganymede, Callisto, or Io), the entry point `EuropaClipperJUICEUVSTool/europajuiceuvs_observationplanningtool.pro` produces estimated detector counts and map visualizations for that window. JUICE UVS appears as a planned second spacecraft option; the checked-in configuration hardcodes Europa Clipper on the 21F31_v4 tour trajectory.

The simulation chain lives in 27 routines under `EuropaClipperJUICEUVSTool/Routines/`:

- per-exposure viewing geometry via SPICE/Icy (`compute_geometry_element.pro`): per-pixel latitude, longitude, incidence, emission, and phase angles for the AP and SP instrument ports;
- radiation background from the Jovian environment (`radiation_detector.pro`), driven by the spacecraft position in dipole magnetic coordinates, with counting noise added (`add_counting_noise.pro`);
- UV surface reflectance from moon albedo maps and a solar spectrum (`surface_reflectance_moon.pro`), folded through the instrument effective area and wavelength solution;
- detector-image output and map plots of counts, phase, and incidence angle (`make_visual_v2.pro`, Coyote graphics).

`EuropaAlbedoMap_IDLSave.py` is a Python bridge: it reads the Voyager/Galileo SSI 500 m global mosaic of Europa with rasterio, builds normalized and UV-scaled albedo arrays, and writes them into an IDL `.sav` file through `idlpy`.

## Repository layout

The repo is about 364 MB because it carries its own inputs: SPICE kernels (`SPICE/`, `Kernels/`), Europa Clipper tour trajectories (`MissionTrajectories/`), base maps (`MapImages/`), and the vendored Coyote IDL graphics library (`coyote/`). `Planning_public/` holds the shareable subset of planning inputs, outputs, and routines. `ObservingTool/` holds the documentation and presentation material, including `Europa UVS Observing Tool Documentation.docx`.

## Provenance

Per the header of the main routine, the core tool was written by the Southwest Research Institute Remote Sensing Group in April 2022; I adapted and extended it starting in May 2023. Paths assume a local checkout pointed to by a `UVSPATH` environment variable, and the code expects IDL with the Icy SPICE interface. There is no license file, so default copyright applies; ask before reusing any part of it.
