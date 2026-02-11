//
//  MixerChannelNames.swift
//  Grainulator
//
//  Shared mixer channel short names used across recording source menus.
//

enum MixerChannel {
    static func shortName(_ channel: Int) -> String {
        switch channel {
        case 0: return "MOS"
        case 1: return "RES"
        case 2: return "GR1"
        case 3: return "LP1"
        case 4: return "LP2"
        case 5: return "GR2"
        case 6: return "DRM"
        case 7: return "KCK"
        case 8: return "SK"
        case 9: return "SNR"
        case 10: return "HH"
        case 11: return "SMP"
        default: return "???"
        }
    }

    static func displayName(_ channel: Int) -> String {
        switch channel {
        case 0: return "Macro Osc"
        case 1: return "Resonator"
        case 2: return "Gran 1"
        case 3: return "Loop 1"
        case 4: return "Loop 2"
        case 5: return "Gran 2"
        case 6: return "Drums"
        case 7: return "Kick"
        case 8: return "Syn Kick"
        case 9: return "Snare"
        case 10: return "Hi-Hat"
        case 11: return "Sampler"
        default: return "???"
        }
    }
}
