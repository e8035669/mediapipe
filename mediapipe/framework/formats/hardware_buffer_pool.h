
#ifndef MEDIAPIPE_FRAMEWORK_FORMATS_HARDWARE_BUFFER_POOL_H_
#define MEDIAPIPE_FRAMEWORK_FORMATS_HARDWARE_BUFFER_POOL_H_
#include <memory>
#include <utility>

#include "absl/log/absl_check.h"
#include "mediapipe/framework/formats/hardware_buffer.h"
#include "mediapipe/gpu/multi_pool.h"
#include "mediapipe/gpu/reusable_pool.h"

namespace mediapipe {

namespace internal {

// Pools HardwareBuffers with identical HardwareBufferSpec.
class HardwareBufferSpecPool : public ReusablePool<HardwareBuffer> {
 public:
  // Creates a pool. This pool will manage buffers of the specified dimensions,
  // and will keep keep_count buffers around for reuse.
  // We enforce creation as a shared_ptr so that we can use a weak reference in
  // the buffers' deleters.
  static std::shared_ptr<HardwareBufferSpecPool> Create(
      HardwareBufferSpec& spec, int keep_count) {
    return Create(spec, {.keep_count = keep_count});
  }
  static std::shared_ptr<HardwareBufferSpecPool> Create(
      const HardwareBufferSpec& spec, const MultiPoolOptions& options) {
    return std::shared_ptr<HardwareBufferSpecPool>(
        new HardwareBufferSpecPool(spec, options));
  }
  static std::unique_ptr<HardwareBuffer> CreateBufferWithoutPool(
      const HardwareBufferSpec& spec) {
    auto hardware_buffer = HardwareBuffer::Create(spec);
    // TODO Don't crash - return absl::Status to caller.
    ABSL_CHECK_OK(hardware_buffer);
    return std::make_unique<HardwareBuffer>(std::move(*hardware_buffer));
  }
  const HardwareBufferSpec& spec() const { return spec_; }

 protected:
  HardwareBufferSpecPool(const HardwareBufferSpec& spec,
                         const MultiPoolOptions& options)
      : ReusablePool<HardwareBuffer>(
            [this] { return CreateBufferWithoutPool(spec_); }, options),
        spec_(spec) {}
  const HardwareBufferSpec spec_;
};

}  // namespace internal

class HardwareBufferPool
    : public MultiPool<internal::HardwareBufferSpecPool, HardwareBufferSpec,
                       std::shared_ptr<HardwareBuffer>> {
 public:
  std::shared_ptr<HardwareBuffer> GetBuffer(const HardwareBufferSpec& spec) {
    return Get(spec);
  }
};

}  // namespace mediapipe

#endif  // MEDIAPIPE_FRAMEWORK_FORMATS_HARDWARE_BUFFER_POOL_H_
