#!/bin/bash
set -eEuo pipefail
cd "$(dirname "$(readlink -f "$0")")"

source bash-buddy/lib/trap_error_info.sh
source bash-buddy/lib/common_utils.sh

################################################################################
# prepare
################################################################################

# shellcheck disable=SC2034
PREPARE_JDKS_INSTALL_BY_SDKMAN=(
    8.322.06.2-amzn
    11.0.14-ms
    17.0.2.8.1-amzn
)

source bash-buddy/lib/prepare_jdks.sh

source bash-buddy/lib/java_build_utils.sh

################################################################################
# ci build logic
################################################################################

cd ..

########################################
# default jdk 11, do build and test
########################################
default_build_jdk_version=11

prepare_jdks::switch_java_home_to_jdk "$default_build_jdk_version"

cu::head_line_echo "build and test with Java: $JAVA_HOME"

jvb::mvn_cmd -DperformRelease -P'!gen-sign' clean install
(
    cd auto-pipeline-examples
    cu::log_then_run ./gradlew clean test
)

########################################
# test multi-version java
# shellcheck disable=SC2154
########################################
for jhome_var_name in "${JDK_HOME_VAR_NAMES[@]}"; do
    # already tested by above `mvn install`
    [ "JDK${default_build_jdk_version}_HOME" = "$jhome_var_name" ] && continue

    prepare_jdks::switch_java_home_to_jdk "${!jhome_var_name}"

    cu::head_line_echo "test with Java: $JAVA_HOME"

    # just test without build
    jvb::mvn_cmd -DperformRelease -P'!gen-sign' surefire:test
    (
        cd auto-pipeline-examples
        cu::log_then_run ./gradlew clean test
    )
done
