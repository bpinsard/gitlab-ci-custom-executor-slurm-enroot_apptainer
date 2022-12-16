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

    TEST_PLAYGROUND=$PWD/$(mktemp -d scriptwrapper-testXXXXXXX)
    export MOCKLOGDIR="$TEST_PLAYGROUND"
    echo "Created test playground at $TEST_PLAYGROUND" >&3
    cd "$TEST_PLAYGROUND" || exit

    export CUSTOM_ENV_CI_BUILDS_DIR="/a/dir/ectory"
    export CUSTOM_ENV_CI_JOB_IMAGE=an-image:latest
    export CUSTOM_ENV_CI_JOB_ID=54321

}


teardown() {

    rm -r "$TEST_PLAYGROUND"
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

@test "enroot start is called in the wrap" {

    SCRIPT_TO_WRAP="$PWD/scrtowrap.sh"
    cat <<EOF > "$SCRIPT_TO_WRAP"
echo "some thing to wrap"
EOF
    chmod +x "$SCRIPT_TO_WRAP"

    "$SRC/script-enroot-wrapper.sh" "$SCRIPT_TO_WRAP" > ./wrapped.sh
    chmod +x ./wrapped.sh

    ./wrapped.sh

    run cat "$MOCKLOGDIR/enroot.log"
    assert_line --regexp "start.*$SCRIPT_TO_WRAP"


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

@test "ENROOT_*_PATH variables are set in the wrap" {

    SCRIPT_TO_WRAP="$PWD/scrtowrap.sh"
    cat <<EOF > "$SCRIPT_TO_WRAP"
echo "something"
EOF
    chmod +x "$SCRIPT_TO_WRAP"

    "$SRC/script-enroot-wrapper.sh" "$SCRIPT_TO_WRAP" > ./wrapped.sh
    chmod +x ./wrapped.sh

    ./wrapped.sh
    cat "$MOCKLOGDIR/enroot.log"
    run cat "$MOCKLOGDIR/enroot.log"
    for VARNAME in ENROOT_RUNTIME_PATH ENROOT_CACHE_PATH ENROOT_DATA_PATH
    do
        assert_output --regexp "${VARNAME}.*${CUSTOM_ENV_CI_BUILDS_DIR}"
    done


}
