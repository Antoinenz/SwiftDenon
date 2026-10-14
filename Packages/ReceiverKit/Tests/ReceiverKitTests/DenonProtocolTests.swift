import Testing
@testable import ReceiverKit

@Suite struct DenonProtocolTests {
    @Test func volumeParsing() {
        #expect(DenonProtocol.parseVolume("50") == 50)
        #expect(DenonProtocol.parseVolume("505") == 50.5)
        #expect(DenonProtocol.parseVolume("MAX") == nil)
    }

    @Test func volumeFormatting() {
        #expect(DenonProtocol.formatVolume(5) == "05")
        #expect(DenonProtocol.formatVolume(50.5) == "505")
        #expect(DenonProtocol.formatVolume(50.2) == "50")
        #expect(DenonProtocol.formatVolume(120) == "98")
    }

    @Test func encoding() {
        #expect(DenonProtocol.encode(.power(zone: 1, on: false)) == ["PWSTANDBY"])
        #expect(DenonProtocol.encode(.power(zone: 2, on: true)) == ["Z2ON"])
        #expect(DenonProtocol.encode(.volume(zone: 1, 40.5)) == ["MV405"])
        #expect(DenonProtocol.encode(.volume(zone: 2, 30)) == ["Z230"])
        #expect(DenonProtocol.encode(.mute(zone: 2, true)) == ["Z2MUON"])
        #expect(DenonProtocol.encode(.input(zone: 1, "BD")) == ["SIBD"])
        #expect(DenonProtocol.encode(.input(zone: 3, "NET")) == ["Z3NET"])
        #expect(DenonProtocol.encode(.bass(3)) == ["PSBAS 53"])
        #expect(DenonProtocol.encode(.sleep(minutes: 5)) == ["SLP005"])
        #expect(DenonProtocol.encode(.sleep(minutes: nil)) == ["SLPOFF"])
    }

    @Test func decodeMainZone() {
        var s = ReceiverState()
        DenonProtocol.apply("PWON", to: &s)
        DenonProtocol.apply("MV435", to: &s)
        DenonProtocol.apply("MVMAX 98", to: &s)
        DenonProtocol.apply("MUON", to: &s)
        DenonProtocol.apply("SIGAME", to: &s)
        DenonProtocol.apply("MSSTEREO", to: &s)
        let z = s.zone(1)!
        #expect(z.power && z.mute)
        #expect(z.volume == 43.5)
        #expect(z.maxVolume == 98)
        #expect(z.input == "GAME")
        #expect(s.soundMode == "STEREO")
    }

    @Test func decodeZone2AndExtras() {
        var s = ReceiverState()
        DenonProtocol.apply("Z2ON", to: &s)
        DenonProtocol.apply("Z245", to: &s)
        DenonProtocol.apply("Z2CD", to: &s)
        DenonProtocol.apply("Z2MUOFF", to: &s)
        DenonProtocol.apply("PSBAS 47", to: &s)
        DenonProtocol.apply("PSDYNEQ ON", to: &s)
        DenonProtocol.apply("SLP030", to: &s)
        let z = s.zone(2)!
        #expect(z.power && !z.mute && z.volume == 45 && z.input == "CD")
        #expect(s.bass == -3)
        #expect(s.dynamicEQ == true)
        #expect(s.sleepMinutes == 30)
    }

    @Test func unknownLinesIgnored() {
        var s = ReceiverState()
        #expect(!DenonProtocol.apply("PSMULTEQ:AUDYSSEY", to: &s))
        #expect(!DenonProtocol.apply("Z2PSBAS 50", to: &s))
    }

    @Test func friendlyNamesAndHiddenSources() {
        var s = ReceiverState()
        for line in ["SSFUNMPLAY Apple TV        ", "SSFUNAUX1 Pool Room", "SSFUN END",
                     "SSSODBD DEL", "SSSODMPLAY USE", "SSSODAUX1 USE", "SSSODTUNER USE", "SSSOD END"] {
            DenonProtocol.apply(line, to: &s)
        }
        #expect(s.inputs.map(\.id) == ["MPLAY", "AUX1", "TUNER"])
        #expect(s.inputs.map(\.name) == ["Apple TV", "Pool Room", "Tuner"])
    }

    @Test func halfStepLearnedFromReports() {
        var s = ReceiverState()
        #expect(s.zone(1)?.halfStep == true)
        DenonProtocol.apply("Z242", to: &s)
        #expect(s.zone(2)?.halfStep == false)
        DenonProtocol.apply("Z2425", to: &s)
        #expect(s.zone(2)?.halfStep == true)
    }

    @Test func zoneSleepLineIsNotAnInput() {
        var s = ReceiverState()
        DenonProtocol.apply("Z2AUX1", to: &s)
        DenonProtocol.apply("Z2SLPOFF", to: &s)
        #expect(s.zone(2)?.input == "AUX1")
    }
}
