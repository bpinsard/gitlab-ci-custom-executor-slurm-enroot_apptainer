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

    TEST_PLAYGROUND="$PWD/script-apptainer-wrapper-test-$BATS_TEST_NAME"
    echo "# Creating test playground at $TEST_PLAYGROUND" >&3
    mkdir "$TEST_PLAYGROUND"
    export MOCKLOGDIR="$TEST_PLAYGROUND"
    cd "$TEST_PLAYGROUND" || exit

    export CUSTOM_ENV_CI_WS="$TEST_PLAYGROUND"
    export CUSTOM_ENV_CI_JOB_IMAGE=an-image:latest
    export CUSTOM_ENV_CI_JOB_ID=54321

    TMPSCR=$(mktemp /tmp/script-apptainer-wrapper-test-script-XXXX.sh)
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

     "$SRC"/script-apptainer-wrapper.sh "$SCRIPT_TO_WRAP" > ./wrapped.sh

      assert [ "$(wc -l < ./wrapped.sh)" -gt 0 ]

}

@test "when the output of the wrapper is executed, the wrapped script is executed " {

    SCRIPT_TO_WRAP="$PWD/scrtowrap.sh"
    cat <<EOF > "$SCRIPT_TO_WRAP"
echo "something to wrap"
EOF
    chmod +x "$SCRIPT_TO_WRAP"

    "$SRC/script-apptainer-wrapper.sh" "$SCRIPT_TO_WRAP" > ./wrapped.sh
    chmod +x ./wrapped.sh

    run ./wrapped.sh
    assert_output "something to wrap"


}

@test "apptainer exec is called in the wrap" {

    SCRIPT_TO_WRAP="$PWD/scrtowrap.sh"
    cat <<EOF > "$SCRIPT_TO_WRAP"
echo "some thing to wrap"
EOF
    chmod +x "$SCRIPT_TO_WRAP"

    "$SRC/script-apptainer-wrapper.sh" "$SCRIPT_TO_WRAP" > ./wrapped.sh
    chmod +x ./wrapped.sh

    ./wrapped.sh

    assert_file_contains "$MOCKLOGDIR/apptainer.log" "exec.*$SCRIPT_TO_WRAP"

}

@test "apptainer exec is called with the image name" {

    SCRIPT_TO_WRAP="$PWD/scrtowrap.sh"
    cat <<EOF > "$SCRIPT_TO_WRAP"
echo "some thing to wrap"
EOF
    chmod +x "$SCRIPT_TO_WRAP"

    "$SRC/script-apptainer-wrapper.sh" "$SCRIPT_TO_WRAP" > ./wrapped.sh
    chmod +x ./wrapped.sh

    ./wrapped.sh

    # shellcheck source=./src/containerlib-apptainer.sh
    source "$SRC/containerlib-apptainer.sh"

    assert_file_contains "$MOCKLOGDIR/apptainer.log" "exec.*$CE_IMAGEFILE"




}



@test "necessary variables are set in the wrap" {

    SCRIPT_TO_WRAP="$PWD/scrtowrap.sh"
    cat <<EOF > "$SCRIPT_TO_WRAP"
echo "something"
EOF
    chmod +x "$SCRIPT_TO_WRAP"

    "$SRC/script-apptainer-wrapper.sh" "$SCRIPT_TO_WRAP" > ./wrapped.sh
    cat ./wrapped.sh
    chmod +x ./wrapped.sh

    ./wrapped.sh
    assert_file_contains "$MOCKLOGDIR/apptainer.log" "APPTAINER_CACHEDIR=$CUSTOM_ENV_CI_WS/.apptainer"

}

@test "apptainer exec uses the right container/image name" {


    SCRIPT_TO_WRAP="$PWD/scrtowrap.sh"
    cat <<EOF > "$SCRIPT_TO_WRAP"
echo "something"
EOF
    chmod +x "$SCRIPT_TO_WRAP"

    "$SRC/script-apptainer-wrapper.sh" "$SCRIPT_TO_WRAP" > ./wrapped.sh
    cat wrapped.sh
    chmod +x ./wrapped.sh

    ./wrapped.sh

    # shellcheck source=./src/containerlib-apptainer.sh
    CE_IMAGEFILE=$( . "$SRC"/containerlib-apptainer.sh; echo "$CE_IMAGEFILE")
    assert_file_contains "$MOCKLOGDIR/apptainer.log" "ARGS: exec.*$CE_IMAGEFILE"

}

@test "apptainer mounts the script file inside the container after CUSTOM_ENV_CI_WS" {

    SCRIPT_TO_WRAP="$PWD/scrtowrap.sh"
    cat <<EOF > "$SCRIPT_TO_WRAP"
echo "something"
EOF
    chmod +x "$SCRIPT_TO_WRAP"

    "$SRC/script-apptainer-wrapper.sh" "$SCRIPT_TO_WRAP" > ./wrapped.sh
    cat wrapped.sh
    chmod +x ./wrapped.sh

    ./wrapped.sh
    assert_file_contains "$MOCKLOGDIR/apptainer.log" "\-\-bind.*$CUSTOM_ENV_CI_WS,$SCRIPT_TO_WRAP"

}

@test "wrapper exits with error EINVAL if script to wrap does not use absolute path" {

    SCRIPT_TO_WRAP="./scrtowrap.sh"
    cat <<EOF > "$SCRIPT_TO_WRAP"
echo "something"
EOF
    chmod +x "$SCRIPT_TO_WRAP"

    run "$SRC/script-apptainer-wrapper.sh" "$SCRIPT_TO_WRAP"
    assert_equal "$status" 22
    assert_output "Needs absolute path to script to wrap."
}
