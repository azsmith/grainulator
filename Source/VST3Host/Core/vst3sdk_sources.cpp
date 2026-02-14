//
//  vst3sdk_sources.cpp
//  Grainulator
//
//  Compiles the minimum VST3 SDK source files needed for hosting.
//  We include them here rather than listing external paths in Package.swift
//  because SPM requires sources to be inside the target directory.
//

// Core IIDs (FUnknown, IBStream, etc.)
#include "pluginterfaces/base/coreiids.cpp"

// FUnknown implementation (FUID, reference counting)
#include "pluginterfaces/base/funknown.cpp"

// UTF-16 string support
#include "pluginterfaces/base/ustring.cpp"

// ========== VST-specific IID definitions ==========
// The VST3 headers use DECLARE_CLASS_IID which only declares.
// We need DEF_CLASS_IID to define the static storage.
#include "pluginterfaces/vst/ivstcomponent.h"
#include "pluginterfaces/vst/ivstaudioprocessor.h"
#include "pluginterfaces/vst/ivsteditcontroller.h"
#include "pluginterfaces/vst/ivstevents.h"
#include "pluginterfaces/vst/ivstparameterchanges.h"
#include "pluginterfaces/gui/iplugview.h"

namespace Steinberg {
namespace Vst {
    DEF_CLASS_IID(IComponent)
    DEF_CLASS_IID(IAudioProcessor)
    DEF_CLASS_IID(IEditController)
}
}
