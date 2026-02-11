// Copyright 2021 Emilie Gillet.
//
// Author: Emilie Gillet (emilie.o.gillet@gmail.com)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
// See http://creativecommons.org/licenses/MIT/ for more information.

#include "plaits_upstream/user_data.h"

#include <algorithm>
#include <array>
#include <cstring>

namespace plaits {

namespace {

constexpr int kMaxSlots = 24;

struct DesktopUserDataStore {
  std::array<std::array<uint8_t, UserData::SIZE>, kMaxSlots> slot_bytes{};
  std::array<bool, kMaxSlots> slot_valid{};
};

DesktopUserDataStore& store() {
  static DesktopUserDataStore s;
  return s;
}

}  // namespace

void SetDesktopUserDataSlot(int slot, const uint8_t* data, size_t size) {
  if (slot < 0 || slot >= kMaxSlots || data == nullptr || size == 0) {
    return;
  }

  auto& s = store();
  const size_t copy_size = std::min(size, static_cast<size_t>(UserData::SIZE));
  std::memcpy(s.slot_bytes[slot].data(), data, copy_size);
  if (copy_size < static_cast<size_t>(UserData::SIZE)) {
    std::memset(
        s.slot_bytes[slot].data() + copy_size,
        0,
        static_cast<size_t>(UserData::SIZE) - copy_size);
  }
  s.slot_valid[slot] = true;
}

void ClearDesktopUserDataSlot(int slot) {
  if (slot < 0 || slot >= kMaxSlots) {
    return;
  }
  auto& s = store();
  s.slot_valid[slot] = false;
}

void ClearAllDesktopUserDataSlots() {
  auto& s = store();
  s.slot_valid.fill(false);
}

const uint8_t* UserData::ptr(int slot) const {
  if (slot < 0 || slot >= kMaxSlots) {
    return NULL;
  }

  auto& s = store();
  if (!s.slot_valid[slot]) {
    return NULL;
  }
  return s.slot_bytes[slot].data();
}

}  // namespace plaits
