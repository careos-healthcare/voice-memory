/// Sentinel used by [copyWith] implementations to distinguish "caller did not
/// pass this argument" from "caller explicitly passed null", so nullable
/// fields can be cleared without a lossy `value ?? existingValue` contract.
class CopyWithUnset {
  const CopyWithUnset();
}

const copyWithUnset = CopyWithUnset();

/// Wraps a possibly-null value that a caller explicitly wants to set,
/// including setting it to null.
class CopyWithValue<T> {
  const CopyWithValue(this.value);
  final T value;
}
