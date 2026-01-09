# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Base Image
FROM quay.io/fedora/fedora-bootc:43

# --- SECURE BOOT KEYS ---
# Expects these files to be in your build context directory
COPY noamd.key /tmp/noamd.key
COPY noamd.crt /etc/pki/noamd/noamd.crt

# --- BUILD EXECUTION ---
# We mount /tmp/noamd.key so it doesn't end up in the final image layer
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache/dnf \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

# --- CLEANUP ---
# Ensure the private key is gone (redundant if using tmpfs, but good practice)
RUN rm -f /tmp/noamd.key

# --- LINTING ---
RUN bootc container lint
