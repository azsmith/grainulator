//
//  ReelBuffer.h
//  Grainulator
//
//  Audio buffer for granular synthesis (Morphagene-style "Reel")
//  Stores up to 2.5 minutes of stereo audio at 48kHz
//

#ifndef REELBUFFER_H
#define REELBUFFER_H

#include <cstdint>
#include <cstddef>
#include <cstring>
#include <algorithm>
#include <atomic>

namespace Grainulator {

/// Splice marker - defines a region within the reel
struct SpliceMarker {
    uint32_t start_sample;      // Start position in samples
    uint32_t end_sample;        // End position in samples
    bool loop_enabled;          // Whether this splice loops
    char name[32];              // Splice name (null-terminated)
    uint8_t color_r, color_g, color_b;  // Display color

    SpliceMarker()
        : start_sample(0)
        , end_sample(0)
        , loop_enabled(true)
        , color_r(74), color_g(158), color_b(255)  // Default blue
    {
        name[0] = '\0';
    }

    uint32_t Length() const {
        return end_sample > start_sample ? end_sample - start_sample : 0;
    }
};

/// Recording mode for ReelBuffer
enum class RecordMode : int {
    OneShot = 0,  // Record linearly until stopped or buffer full
    LiveLoop = 1  // Record head loops, feedback controls overdub
};

/// ReelBuffer - holds audio data and splice markers
/// Capacity: 2.5 minutes @ 48kHz stereo = 7,200,000 samples per channel
class ReelBuffer {
public:
    // Constants
    static constexpr size_t kMaxDurationSeconds = 150;  // 2.5 minutes
    static constexpr size_t kDefaultSampleRate = 48000;
    static constexpr size_t kMaxSamples = kMaxDurationSeconds * kDefaultSampleRate;  // 7.2M samples
    static constexpr size_t kMaxRecordSamples = 120 * kDefaultSampleRate;  // 2 minutes recording limit
    static constexpr size_t kMaxSplices = 300;
    static constexpr size_t kNumChannels = 2;  // Stereo

    ReelBuffer()
        : sample_rate_(kDefaultSampleRate)
        , length_(0)
        , num_splices_(0)
        , is_recording_(false)
        , record_position_(0)
        , record_mode_(static_cast<int>(RecordMode::OneShot))
        , feedback_(0.0f)
        , loop_length_(0)
    {
        // Allocate audio buffers
        buffer_left_ = new float[kMaxSamples];
        buffer_right_ = new float[kMaxSamples];

        // Initialize to silence
        Clear();

        // Create default splice covering entire buffer
        splices_[0].start_sample = 0;
        splices_[0].end_sample = 0;
        splices_[0].loop_enabled = true;
        std::strncpy(splices_[0].name, "Default", 31);
        num_splices_ = 1;
    }

    ~ReelBuffer() {
        delete[] buffer_left_;
        delete[] buffer_right_;
    }

    // ========== Buffer Access ==========

    /// Get sample at position (with interpolation for fractional positions)
    /// channel: 0 = left, 1 = right
    float GetSample(size_t channel, float position) const {
        if (length_ == 0) return 0.0f;

        // Clamp position
        if (position < 0.0f) position = 0.0f;
        if (position >= static_cast<float>(length_)) position = static_cast<float>(length_ - 1);

        // Integer and fractional parts
        size_t index = static_cast<size_t>(position);
        float frac = position - static_cast<float>(index);

        // Get buffer pointer
        const float* buffer = (channel == 0) ? buffer_left_ : buffer_right_;

        // Linear interpolation
        float sample1 = buffer[index];
        float sample2 = (index + 1 < length_) ? buffer[index + 1] : sample1;

        return sample1 + frac * (sample2 - sample1);
    }

    /// Get sample at integer position (no interpolation)
    float GetSampleInt(size_t channel, size_t position) const {
        if (position >= length_) return 0.0f;
        return (channel == 0) ? buffer_left_[position] : buffer_right_[position];
    }

    /// Write sample at position
    void SetSample(size_t channel, size_t position, float value) {
        if (position >= kMaxSamples) return;

        if (channel == 0) {
            buffer_left_[position] = value;
        } else {
            buffer_right_[position] = value;
        }

        // Update length if writing beyond current length
        if (position >= length_) {
            length_ = position + 1;
        }
    }

    /// Get pointer to buffer for bulk operations (use with care)
    const float* GetBufferPointer(size_t channel) const {
        return (channel == 0) ? buffer_left_ : buffer_right_;
    }

    float* GetBufferPointerMutable(size_t channel) {
        return (channel == 0) ? buffer_left_ : buffer_right_;
    }

    // ========== Buffer Management ==========

    /// Clear the entire buffer to silence
    void Clear() {
        std::memset(buffer_left_, 0, kMaxSamples * sizeof(float));
        std::memset(buffer_right_, 0, kMaxSamples * sizeof(float));
        length_ = 0;

        // Reset to single default splice
        splices_[0].start_sample = 0;
        splices_[0].end_sample = 0;
        splices_[0].loop_enabled = true;
        num_splices_ = 1;
    }

    /// Set the buffer length (in samples)
    void SetLength(size_t length) {
        length_ = std::min(length, kMaxSamples);

        // Update default splice to cover entire buffer
        if (num_splices_ > 0) {
            splices_[0].end_sample = static_cast<uint32_t>(length_);
        }
    }

    size_t GetLength() const { return length_; }
    size_t GetMaxLength() const { return kMaxSamples; }

    float GetSampleRate() const { return sample_rate_; }
    void SetSampleRate(float rate) { sample_rate_ = rate; }

    /// Get duration in seconds
    float GetDurationSeconds() const {
        return static_cast<float>(length_) / sample_rate_;
    }

    // ========== Splice Management ==========

    size_t GetNumSplices() const { return num_splices_; }

    const SpliceMarker& GetSplice(size_t index) const {
        if (index >= num_splices_) {
            static SpliceMarker empty;
            return empty;
        }
        return splices_[index];
    }

    SpliceMarker& GetSpliceMutable(size_t index) {
        static SpliceMarker empty;
        if (index >= num_splices_) return empty;
        return splices_[index];
    }

    /// Add a new splice at the specified position
    /// Returns the index of the new splice, or -1 if failed
    int AddSplice(uint32_t start, uint32_t end, const char* name = nullptr) {
        if (num_splices_ >= kMaxSplices) return -1;
        if (end <= start) return -1;

        size_t index = num_splices_;
        splices_[index].start_sample = start;
        splices_[index].end_sample = end;
        splices_[index].loop_enabled = true;

        if (name) {
            std::strncpy(splices_[index].name, name, 31);
            splices_[index].name[31] = '\0';
        } else {
            snprintf(splices_[index].name, 31, "Splice %zu", index);
        }

        num_splices_++;
        return static_cast<int>(index);
    }

    /// Remove a splice by index
    bool RemoveSplice(size_t index) {
        if (index >= num_splices_ || num_splices_ <= 1) return false;

        // Shift remaining splices down
        for (size_t i = index; i < num_splices_ - 1; ++i) {
            splices_[i] = splices_[i + 1];
        }
        num_splices_--;
        return true;
    }

    /// Create a splice at current position (splits the active splice)
    int SplitSpliceAt(size_t splice_index, uint32_t position) {
        if (splice_index >= num_splices_) return -1;
        if (num_splices_ >= kMaxSplices) return -1;

        SpliceMarker& current = splices_[splice_index];
        if (position <= current.start_sample || position >= current.end_sample) {
            return -1;  // Position must be within the splice
        }

        // Create new splice for the second half
        uint32_t original_end = current.end_sample;
        current.end_sample = position;

        return AddSplice(position, original_end, nullptr);
    }

    // ========== Recording ==========

    bool IsRecording() const { return is_recording_; }

    RecordMode GetRecordMode() const {
        return static_cast<RecordMode>(record_mode_.load(std::memory_order_relaxed));
    }

    void SetRecordMode(RecordMode mode) {
        record_mode_.store(static_cast<int>(mode), std::memory_order_relaxed);
    }

    float GetFeedback() const { return feedback_.load(std::memory_order_relaxed); }
    void SetFeedback(float fb) { feedback_.store(fb, std::memory_order_relaxed); }

    size_t GetLoopLength() const { return loop_length_; }
    void SetLoopLength(size_t samples) {
        loop_length_ = std::min(samples, kMaxRecordSamples);
    }

    /// Start recording in the specified mode
    void StartRecording(RecordMode mode) {
        record_mode_.store(static_cast<int>(mode), std::memory_order_relaxed);
        // Always reset record position when starting a fresh recording.
        // This prevents issues when switching modes (e.g. OneShot leaves
        // record_position_ at the end of the buffer, which would cause
        // LiveLoop to immediately wrap or fail).
        record_position_ = 0;
        is_recording_ = true;
    }

    /// Legacy overload — defaults to OneShot
    void StartRecording() {
        StartRecording(RecordMode::OneShot);
    }

    void StopRecording() {
        is_recording_ = false;
        RecordMode mode = GetRecordMode();
        if (mode == RecordMode::OneShot) {
            SetLength(record_position_);
        }
        // LiveLoop: length stays as loop_length_, don't change it
    }

    /// Record a stereo sample pair (OneShot mode — no feedback)
    void RecordSample(float left, float right) {
        if (!is_recording_ || record_position_ >= kMaxRecordSamples) {
            if (is_recording_ && record_position_ >= kMaxRecordSamples) {
                StopRecording();  // Auto-stop at limit
            }
            return;
        }

        buffer_left_[record_position_] = left;
        buffer_right_[record_position_] = right;
        record_position_++;
    }

    /// Record a stereo sample pair with feedback (for both modes)
    /// In OneShot mode: destructive write, stops at kMaxRecordSamples
    /// In LiveLoop mode: blends with existing buffer using feedback, wraps at loop_length_
    void RecordSampleWithFeedback(float left, float right) {
        if (!is_recording_) return;

        RecordMode mode = GetRecordMode();

        if (mode == RecordMode::OneShot) {
            if (record_position_ >= kMaxRecordSamples) {
                StopRecording();
                return;
            }
            buffer_left_[record_position_] = left;
            buffer_right_[record_position_] = right;
            record_position_++;
            // Update length as we record so playback can see new content
            if (record_position_ > length_) {
                length_ = record_position_;
            }
        } else {
            // LiveLoop mode
            if (loop_length_ == 0) return;
            if (record_position_ >= loop_length_) {
                record_position_ = 0;
            }
            float fb = feedback_.load(std::memory_order_relaxed);
            buffer_left_[record_position_] = buffer_left_[record_position_] * fb + left;
            buffer_right_[record_position_] = buffer_right_[record_position_] * fb + right;
            record_position_++;
            if (record_position_ >= loop_length_) {
                record_position_ = 0;
            }
        }
    }

    size_t GetRecordPosition() const { return record_position_; }

    /// Get normalized record position (0-1) for UI display
    float GetNormalizedRecordPosition() const {
        RecordMode mode = GetRecordMode();
        if (mode == RecordMode::LiveLoop) {
            return loop_length_ > 0 ? static_cast<float>(record_position_) / static_cast<float>(loop_length_) : 0.0f;
        }
        return kMaxRecordSamples > 0 ? static_cast<float>(record_position_) / static_cast<float>(kMaxRecordSamples) : 0.0f;
    }

    // ========== Waveform Overview (for UI) ==========

    /// Generate downsampled waveform overview for display
    /// output_size: number of output samples (e.g., 1000 for 1000-pixel display)
    /// output: array to fill with peak values (interleaved min/max pairs)
    void GenerateOverview(float* output, size_t output_size) const {
        if (length_ == 0 || output_size == 0) {
            std::memset(output, 0, output_size * 2 * sizeof(float));
            return;
        }

        float samples_per_pixel = static_cast<float>(length_) / static_cast<float>(output_size);

        for (size_t i = 0; i < output_size; ++i) {
            size_t start = static_cast<size_t>(i * samples_per_pixel);
            size_t end = static_cast<size_t>((i + 1) * samples_per_pixel);
            end = std::min(end, length_);

            float min_val = 1.0f;
            float max_val = -1.0f;

            for (size_t j = start; j < end; ++j) {
                // Mix L+R for mono overview
                float sample = (buffer_left_[j] + buffer_right_[j]) * 0.5f;
                min_val = std::min(min_val, sample);
                max_val = std::max(max_val, sample);
            }

            output[i * 2] = min_val;
            output[i * 2 + 1] = max_val;
        }
    }

private:
    float* buffer_left_;
    float* buffer_right_;
    float sample_rate_;
    size_t length_;  // Current used length in samples

    SpliceMarker splices_[kMaxSplices];
    size_t num_splices_;

    std::atomic<bool> is_recording_;
    size_t record_position_;
    std::atomic<int> record_mode_;       // RecordMode enum (set from UI, read from audio thread)
    std::atomic<float> feedback_;        // 0-1 feedback for LiveLoop (set from UI, read from audio thread)
    size_t loop_length_;                 // Loop length in samples for LiveLoop mode

    // Prevent copying (large buffers)
    ReelBuffer(const ReelBuffer&) = delete;
    ReelBuffer& operator=(const ReelBuffer&) = delete;
};

} // namespace Grainulator

#endif // REELBUFFER_H
