# SPICE model artifact

Google's published SPICE Lite graph is Apache-2.0 but contains the Select TF
operator `FlexRFFT`. The compact TFLite runtime used by this app deliberately
does not bundle the large Flex runtime, so the original TF Hub artifact must
not be placed in the default downloader.

Publish a reviewed SPICE TFLite graph that uses only the operators supported by
the target Android/iOS runtime, validate it with `SpiceTfliteRunner`, and put
its HTTPS URL and SHA-256 in the remote model manifest. The runner validates
the float input/output contract and fails clearly if an incompatible graph is
configured.
