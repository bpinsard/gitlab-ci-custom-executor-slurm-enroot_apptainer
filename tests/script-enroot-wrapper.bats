#!/usr/bin/env bash

setup(){

    load './test_helper/bats-support/load'
    load './test_helper/bats-assert/load'
    load './test_helper/bats-file/load'
    load './test-utils'

    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/.." > /dev/null 2>&1 && pwd)"
    export PROJECT_ROOT
    load_mocks

    SRC="$PROJECT_ROOT"/src

    TEST_PLAYGROUND="$PWD/script-enroot-wrapper-test-$BATS_TEST_NAME"
    echo "# Creating test playground at $TEST_PLAYGROUND" >&3
    mkdir "$TEST_PLAYGROUND"
    export MOCKLOGDIR="$TEST_PLAYGROUND"
    cd "$TEST_PLAYGROUND" || exit

    export CUSTOM_ENV_CI_WS="$TEST_PLAYGROUND"
    export CUSTOM_ENV_CI_BUILDS_DIR="$TEST_PLAYGROUND"
    export CUSTOM_ENV_CI_JOB_IMAGE=docker://an-image:latest
    export CUSTOM_ENV_CI_JOB_ID=54321

    TMPSCR=$(mktemp /tmp/script-enroot-wrapper-test-script-XXXX.sh)
}


teardown() {

    try_to_remove_dir "$TEST_PLAYGROUND"
    rm -f "$TMPSCR"
}


@test "the wrapper can be called with a script and outputs a script on stdout " {

    SCRIPT_TO_WRAP="$PWD/scrtowrap.sh"
    cat <<EOF > "$SCRIPT_TO_WRAP"
echo "some thing to wrap"
EOF

     "$SRC"/script-enroot-wrapper.sh "$SCRIPT_TO_WRAP" > ./wrapped.sh

      assert [ "$(wc -l < ./wrapped.sh)" -gt 0 ]

}

@test "when the output of the wrapper is executed, the wrapped script is executed " {

    SCRIPT_TO_WRAP="$PWD/scrtowrap.sh"
    cat <<EOF > "$SCRIPT_TO_WRAP"
echo "something to wrap"
EOF
    chmod +x "$SCRIPT_TO_WRAP"

    "$SRC/script-enroot-wrapper.sh" "$SCRIPT_TO_WRAP" > ./wrapped.sh
    chmod +x ./wrapped.sh

    run ./wrapped.sh
    assert_output "something to wrap"


}

@test "no env var crap in the wrap" {

    SCRIPT_TO_WRAP="$PWD/scrtowrap.sh"
    cat <<EOF > "$SCRIPT_TO_WRAP"
echo "something"
EOF
    chmod +x "$SCRIPT_TO_WRAP"

    "$SRC/script-enroot-wrapper.sh" "$SCRIPT_TO_WRAP" > ./wrapped.sh

    assert [ "$(wc -l < ./wrapped.sh)" -lt 50 ]
}

@test "enroot start is called in the wrap" {

    SCRIPT_TO_WRAP="$PWD/scrtowrap.sh"
    cat <<EOF > "$SCRIPT_TO_WRAP"
echo "some thing to wrap"
EOF
    chmod +x "$SCRIPT_TO_WRAP"

    "$SRC/script-enroot-wrapper.sh" "$SCRIPT_TO_WRAP" > ./wrapped.sh
    chmod +x ./wrapped.sh

    ./wrapped.sh

    assert_file_contains "$MOCKLOGDIR/enroot.log" "start.*$SCRIPT_TO_WRAP"


}


@test "ENROOT_*_PATH variables are set in the wrap" {

    SCRIPT_TO_WRAP="$PWD/scrtowrap.sh"
    cat <<EOF > "$SCRIPT_TO_WRAP"
echo "something"
EOF
    chmod +x "$SCRIPT_TO_WRAP"

    "$SRC/script-enroot-wrapper.sh" "$SCRIPT_TO_WRAP" > ./wrapped.sh
    chmod +x ./wrapped.sh

    echo "Wrap produced:"
    echo "====================="
    cat ./wrapped.sh
    echo "====================="
    ./wrapped.sh

    echo "Log: "
    echo "====================="
    cat "$MOCKLOGDIR/enroot.log"
    echo "====================="
    for VARNAME in ENROOT_RUNTIME_PATH ENROOT_CACHE_PATH ENROOT_DATA_PATH
    do
        assert_file_contains "$MOCKLOGDIR/enroot.log" "${VARNAME}.*${CUSTOM_ENV_CI_WS}"
    done


}

@test "enroot start uses the right container name" {


    SCRIPT_TO_WRAP="$PWD/scrtowrap.sh"
    cat <<EOF > "$SCRIPT_TO_WRAP"
echo "echoing something from the script to wrap"
EOF
    chmod +x "$SCRIPT_TO_WRAP"

    "$SRC/script-enroot-wrapper.sh" "$SCRIPT_TO_WRAP" > ./wrapped.sh
    chmod +x ./wrapped.sh

    ./wrapped.sh

    # shellcheck source=./src/containerlib-enroot.sh
    CONTAINER_NAME=$( . "$SRC"/containerlib-enroot.sh; echo "$CE_CONTAINER_NAME")

    assert_file_contains "$MOCKLOGDIR/enroot.log" "ARGS: start.*$CONTAINER_NAME"

}

@test "enroot uses --rw" {

    SCRIPT_TO_WRAP="$PWD/scrtowrap.sh"
    cat <<EOF > "$SCRIPT_TO_WRAP"
echo "something"
EOF
    chmod +x "$SCRIPT_TO_WRAP"

    "$SRC/script-enroot-wrapper.sh" "$SCRIPT_TO_WRAP" > ./wrapped.sh
    chmod +x ./wrapped.sh

    ./wrapped.sh
    assert_file_contains "$MOCKLOGDIR/enroot.log" "ARGS: start.*--rw"


}

@test "enroot DOES NOT mount the script file inside the container if it is in CUSTOM_ENV_CI_WS" {

    SCRIPT_TO_WRAP="$PWD/scrtowrap.sh"
    cat <<EOF > "$SCRIPT_TO_WRAP"
echo "something"
EOF
    chmod +x "$SCRIPT_TO_WRAP"

    "$SRC/script-enroot-wrapper.sh" "$SCRIPT_TO_WRAP" > ./wrapped.sh
    chmod +x ./wrapped.sh

    ./wrapped.sh
    run cat "$MOCKLOGDIR/enroot.log"
    refute_output --regexp "--mount.*$SCRIPT_TO_WRAP:$SCRIPT_TO_WRAP"

}

@test "enroot DOES mount the script file inside the container if it is OUTSIDE CUSTOM_ENV_CI_WS" {

    SCRIPT_TO_WRAP="$TMPSCR"
    cat <<EOF > "$SCRIPT_TO_WRAP"
echo "something"
EOF
    chmod +x "$SCRIPT_TO_WRAP"

    "$SRC/script-enroot-wrapper.sh" "$SCRIPT_TO_WRAP" > ./wrapped.sh
    chmod +x ./wrapped.sh

    ./wrapped.sh
    assert_file_contains "$MOCKLOGDIR/enroot.log" "\-\-mount.*$SCRIPT_TO_WRAP:$SCRIPT_TO_WRAP"

}


@test "enroot mounts CUSTOM_ENV_CI_WS inside the container" {

    SCRIPT_TO_WRAP="$PWD/scrtowrap.sh"
    cat <<EOF > "$SCRIPT_TO_WRAP"
echo "something"
EOF
    chmod +x "$SCRIPT_TO_WRAP"

    "$SRC/script-enroot-wrapper.sh" "$SCRIPT_TO_WRAP" > ./wrapped.sh
    chmod +x ./wrapped.sh

    ./wrapped.sh
    assert_file_contains "$MOCKLOGDIR/enroot.log" "\-\-mount.*$CUSTOM_ENV_CI_WS:$CUSTOM_ENV_CI_WS"

}


@test "wrapper exits with error EINVAL if script to wrap does not use absolute path" {

    SCRIPT_TO_WRAP="./scrtowrap.sh"
    cat <<EOF > "$SCRIPT_TO_WRAP"
echo "something"
EOF
    chmod +x "$SCRIPT_TO_WRAP"

    run "$SRC/script-enroot-wrapper.sh" "$SCRIPT_TO_WRAP"
    assert_equal "$status" 22
    assert_output "Needs absolute path to script to wrap."
}

@test "enroot DOES NOT mount the CI_BUILDS_DIR inside the container if it is in CI_WS" {

    # Not actually created!
    # shellcheck disable=SC2030
    export CUSTOM_ENV_CI_BUILDS_DIR="$CUSTOM_ENV_CI_WS/builds"

    SCRIPT_TO_WRAP="$TMPSCR"
    touch "$SCRIPT_TO_WRAP"
    chmod +x "$SCRIPT_TO_WRAP"


    "$SRC/script-enroot-wrapper.sh" "$SCRIPT_TO_WRAP" > ./wrapped.sh
    chmod +x ./wrapped.sh

    ./wrapped.sh
    run cat "$MOCKLOGDIR/enroot.log"
    refute_output --regexp "--mount.*$CUSTOM_ENV_CI_BUILDS_DIR:$CUSTOM_ENV_CI_BUILDS_DIR"

}

@test "enroot DOES mount the CI_BUILDS_DIR inside the container if it is outside of CI_WS" {

    # Not actually created!
    # shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_CI_BUILDS_DIR="$HOME/builds"

    SCRIPT_TO_WRAP="$TMPSCR"
    touch "$SCRIPT_TO_WRAP"
    chmod +x "$SCRIPT_TO_WRAP"

    "$SRC/script-enroot-wrapper.sh" "$SCRIPT_TO_WRAP" > ./wrapped.sh
    chmod +x ./wrapped.sh

    ./wrapped.sh
    assert_file_contains "$MOCKLOGDIR/enroot.log" \
                         "\-\-mount.*$CUSTOM_ENV_CI_BUILDS_DIR:$CUSTOM_ENV_CI_BUILDS_DIR"

}
