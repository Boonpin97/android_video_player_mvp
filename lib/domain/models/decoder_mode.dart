enum DecoderMode {
  hw('HW', 'mediacodec-copy', 'Hardware decoding with compatibility rendering'),
  hwPlus('HW+', 'mediacodec', 'Hardware decoding with direct rendering'),
  sw('SW', 'no', 'Software decoding for the widest format support');

  const DecoderMode(this.label, this.hwdec, this.description);
  final String label;
  final String hwdec;
  final String description;
}
