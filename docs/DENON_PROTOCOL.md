# Denon / Marantz protocol notes

Control port: TCP **23**, ASCII, commands end with `\r`. The receiver pushes unsolicited status lines. Queries use `?`.

## Commands used

| Purpose | Send | Receive |
| --- | --- | --- |
| Main zone power | `ZMON` / `ZMOFF` | `ZMON` / `ZMOFF` |
| Wake whole unit | `PWON` | `PWON` |
| Whole unit standby | `PWSTANDBY` (not used for zone power) | `PWSTANDBY` |
| Zone 2/3 power | `Z2ON` `Z2OFF` `Z3ON` `Z3OFF` | same |
| Main volume | `MV45`, `MV455` (=45.5), `MVUP`, `MVDOWN` | `MV45`, `MV455`, `MVMAX 98` |
| Zone volume | `Z245` | `Z245` |
| Mute | `MUON` / `MUOFF`, `Z2MUON` | same |
| Input | `SIGAME`, `Z2NET` | same |
| Sound mode | `MSSTEREO` etc. | same |
| Bass / treble | `PSBAS 53` (50 = 0 dB, ±6) | `PSBAS 47` |
| Subwoofer | `PSSWL 50` (50 = 0 dB, ±12) | same |
| Dynamic EQ | `PSDYNEQ ON` | same |
| Sleep | `SLP030`, `SLPOFF` | same |
| Input names | `SSFUN ?` | `SSFUNMPLAY Apple TV` … `SSFUN END` |
| Input visibility | `SSSOD ?` | `SSSODBD DEL` (hidden) / `USE`, … `SSSOD END` |
| Device friendly name | `NSFRN ?` | `NSFRN Denon Amp` |

A full refresh sends `PW? ZM? MV? MU? SI? MS? Z2? Z3? PSBAS ? PSTRE ? PSSWL ? PSDYNEQ ? SLP? SSFUN ? SSSOD ? NSFRN ?`.

## Things learned from real hardware (AVR-X2700H)

- **`PWSTANDBY` turns off every zone.** Main-zone power must use `ZMON`/`ZMOFF`; to power on from full standby send `PWON` then `ZMON`. Sending `PWSTANDBY` for "Main off" also switched Zone 2 off (bug found during testing, fixed).
- **`PWON` says nothing about the main zone.** The amp can be `PWON` with `ZMOFF` and `Z2ON`. Only `ZM*`, `Z2*`, `Z3*` report zone power; `PWSTANDBY` clears all zones.
- **Half-step volume is main-zone only in practice.** Main reports 3 digits (`MV525` = 52.5); Zone 2 reports whole numbers (`Z242`). The app learns `halfStep` per zone from the digit count of reports, defaulting to main = yes, others = no.
- **Zone lines carry more than inputs.** `Z2SLPOFF` is a sleep line, not an input called "SLPOFF". Zone inputs are only accepted if the token is a known source code.
- **Sources**: `SSFUN` lists names only for sources that have been renamed or exist as functions; `SSSOD` lists all sources with `USE`/`DEL`. The app orders by `SSSOD`, names from `SSFUN`, falling back to defaults (`TUNER` → "Tuner", `NET` → "HEOS").
- **Zone names are not readable.** The amp advertises a "ZoneRename" capability, but none of `SSZNA ?`, `SSZN ?`, `Z2NAME ?`, the legacy `/goform/formMainZone_MainZoneXml.xml`, or `AppCommand.xml` (`GetZoneName`, `GetRenameZone`) returned names (empty replies or HTTP 403). Zone names are therefore stored locally in the app (max 12 characters).
- **Web interface**: port 80 answers with a 301 (nginx → HTTPS), port 8080 serves legacy `goform` endpoints (`Deviceinfo.xml` works). The app checks port 80 with a HEAD request that does not follow redirects and shows an "Open web interface" button if it answers.
- **Connection limit**: the amp seems to accept only a limited number of simultaneous control connections. While the app is connected, a separate scan or script may not get through.
- **Commands need ~50 ms spacing**; faster input is dropped.
- `Deviceinfo.xml` (port 8080) reports `DeviceZones` (2 for this model) and capabilities.
