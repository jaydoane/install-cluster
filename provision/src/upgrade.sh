#!/bin/bash
set -ex

# upgrade a db node from one version of Cloudant Local to another

# see e.g.:
# http://www.ibm.com/support/knowledgecenter/SSTPQH_1.0.0/com.ibm.cloudant.local.install.doc/topics/clinstall_upgrading_db_node.html

# requires bash 4 for associative arrays
declare -A installer
installer[1.0.0.2]=CLO_DLL_EDI_1.0_LNX_X86-64_RHT_CT.tar.gz
installer[1.0.0.3]=MFPL_CLDLE_1.0.0.3_LX8664_RH_COS_.tar.gz
installer[1.0.0.5]=IBM_CLOUDANT_DATA_LAYER_LOCAL_ED_.tar.gz

usage() {
    echo "usage: upgrade.sh FROM_VERSION TO_VERSION"
    echo "supported upgrades: 1.0.0.2 to 1.0.0.3, 1.0.0.2 to 1.0.0.5, or 1.0.0.3 to 1.0.0.5"
}

archive() {
    local from_version=$1
    mv /opt/cloudant /opt/cloudant_$from_version
    mv /var/log/cloudant /var/log/cloudant_$from_version
    mv /root/Cloudant /root/Cloudant_$from_version
}

archive_etc_sv() {
    local from_version=$1
    mv /etc/sv/cloudant /etc/sv/cloudant_$from_version
    mv /etc/sv/clouseau /etc/sv/clouseau_$from_version
    mv /etc/sv/cloudant-local-metrics /etc/sv/cloudant-local-metrics_$from_version
}

upgrade_common() {
    local from_version=$1; local to_version=$2
    /root/Cloudant/repo/cloudant.sh -k # shut down services
    archive $from_version
    if [[ $from_version == 1.0.0.2 ]]; then
        rpm -e --noscripts cloudant-local-metrics
    fi
    cd /root/Cloudant_$from_version && ./uninstall.sh -q -r
    # archive_etc_sv $from_version
    mkdir /root/$to_version && cd /root/$to_version
    cp /vagrant/provision/installers/${installer[$to_version]} .
    tar xfz ${installer[$to_version]}
}

upgrade_no_cast() {
    local from_version=$1; local to_version=$2
    upgrade_common $from_version $to_version
    ./quiet_install.sh -a -d -E
    /bin/cp -b /root/Cloudant_$from_version/repo/configure.ini /root/Cloudant/repo/
    /bin/cp -b /root/Cloudant_$from_version/repo/configure.sh /root/Cloudant/repo/
    cd /root/Cloudant/repo && ./configure.sh -q
}

upgrade_to_cast() {
    local from_version=$1; local to_version=$2
    upgrade_common $from_version $to_version
    pip install requests --upgrade
    cd /root/$to_version/cloudant-installer && \
        ./install.bin -i silent -f production.properties
    cast system install --maintenance -p pass -db
    cast cluster export dbnode.yaml.tmp
    cookie=`grep setcookie /opt/cloudant_$from_version/etc/vm.args | cut -d ' ' -f 2`
    sed -e "s/cookie: [a-zA-Z0-9]*/cookie: $cookie/" dbnode.yaml.tmp > dbnode.yaml
    cast node config dbnode.yaml
    cast node maintenance --false
}

from_version=$1
to_version=$2

echo "upgrade version $from_version to $to_version using ${installer[$to_version]}"

if [[ $from_version == 1.0.0.2 ]] && [[ $to_version == 1.0.0.3 ]]; then
    upgrade_no_cast $from_version $to_version
elif [[ $from_version == 1.0.0.2 ]] && [[ $to_version == 1.0.0.5 ]]; then
    upgrade_to_cast $from_version $to_version
elif [[ $from_version == 1.0.0.3 ]] && [[ $to_version == 1.0.0.5 ]]; then
    upgrade_to_cast $from_version $to_version
else
    usage
fi
