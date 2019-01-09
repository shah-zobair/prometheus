#!/bin/bash


########################################################
# This script will prepare all the deployment scripts for deploying prometheus.

# Make sure you have pushed following images to Internal OpenShift registry and into openshift repositry.

# kube-state-metrics
# blackbox-exporter
# prometheus-node-exporter
# grafana-ocp
# haproxy-exporter


#Example:
#100.124.35.26:5000/openshift/kube-state-metrics                  latest              49dfd221b31d        7 weeks ago         242.8 MB
#100.124.35.26:5000/openshift/blackbox-exporter                   latest              b45089678662        9 weeks ago         18.64 MB
#100.124.35.26:5000/openshift/prometheus-node-exporter            latest              9971c9a78974        10 weeks ago        209.1 MB
#100.124.35.26:5000/openshift/grafana-ocp			  latest
#100.124.35.26:5000/openshift/haproxy-exporter			  latest


#########################################################
#########################################################

#export KUBECONFIG=/etc/origin/master/admin.kubeconfig; oc login -u system:admin > /dev/null; oc whoami

oc login -u system:admin

##########################
# Expose routes for Routers
##########################

#for DC in `oc get dc | grep router | cut -f1`;do
#    oc env dc $DC ROUTER_METRICS_TYPE-
#done

#for SERVICE in `oc get svc -n default | grep router | awk {'print $1'}`; do
#    PORT=`oc get svc $SERVICE -n default| grep -o 19..`
#    oc expose service $SERVICE --port=$PORT -n default
#    echo $SERVICE $PORT
    
#done

##########################
# Prepare haproxy-exporter template file for each router pod
##########################

#REGISTRY_IP=`oc get svc -n default | grep docker-registry | awk {'print $2'}`
REGISTRY_IP=docker-registry.default.svc.cluster.local
#INFRA1_IP=`oc describe ep router -n default | grep Addresses | grep -v NotReadyAddresses | awk {'print $2'} | cut -f1 -d,`
#INFRA2_IP=`oc describe ep router -n default | grep Addresses | grep -v NotReadyAddresses | awk {'print $2'} | cut -f2 -d,`
#INFRA3_IP=`oc describe ep router -n default | grep Addresses | grep -v NotReadyAddresses | awk {'print $3'} | cut -f2 -d,`
#ROUTER_PORT=`oc get svc router -n default | grep -o 19..`
#ROUTER_PASSWORD=`oc describe dc router -n default | grep STATS_PASSWORD | awk {'print $2'}`
#I=0

#for ROUTE in `oc get route -n  default | grep router | awk {'print $2'}`; do
#    ROUTER_PORT=$ROUTER_PORT

#    cp haproxy-template.yml haproxy-$I-1.yml
#    cp haproxy-template.yml haproxy-$I-2.yml
#    cp haproxy-template.yml haproxy-$I-3.yml

#    sed -i s/haproxy-exporter-template/haproxy-exporter-$I-1/g haproxy-$I-1.yml
#    sed -i s/haproxy-exporter-template/haproxy-exporter-$I-2/g haproxy-$I-2.yml
#    sed -i s/haproxy-exporter-template/haproxy-exporter-$I-3/g haproxy-$I-3.yml

#    sed -i s/REGISTRY-IP/$REGISTRY_IP/g haproxy-$I-1.yml
#    sed -i s/REGISTRY-IP/$REGISTRY_IP/g haproxy-$I-2.yml
#    sed -i s/REGISTRY-IP/$REGISTRY_IP/g haproxy-$I-3.yml

#    sed -i s/ROUTER-IP/$INFRA1_IP/g haproxy-$I-1.yml
#    sed -i s/ROUTER-IP/$INFRA2_IP/g haproxy-$I-2.yml
#    sed -i s/ROUTER-IP/$INFRA3_IP/g haproxy-$I-3.yml

#    sed -i s/ROUTER-PORT/$ROUTER_PORT/g haproxy-$I-1.yml
#    sed -i s/ROUTER-PORT/$ROUTER_PORT/g haproxy-$I-2.yml
#    sed -i s/ROUTER-PORT/$ROUTER_PORT/g haproxy-$I-3.yml


#    sed -i s/ROUTER-PASS/$ROUTER_PASSWORD/g haproxy-$I-1.yml
#    sed -i s/ROUTER-PASS/$ROUTER_PASSWORD/g haproxy-$I-2.yml
#    sed -i s/ROUTER-PASS/$ROUTER_PASSWORD/g haproxy-$I-3.yml

#    ((I++))
#    ((ROUTER_PORT++))

#done


##########################
# Configure prometheus config map for blackbox-exporter
##########################


MASTER_URL=`grep ^masterPublicURL: /etc/origin/master/master-config.yaml | cut -f2 -d" " | sed s/"https:\/\/"//g | cut -f1 -d:`
MASTER_PORT=`grep ^masterPublicURL: /etc/origin/master/master-config.yaml | cut -f2 -d" " | sed s/"https:\/\/"//g | cut -f2 -d:`
#REGISTRY_URL=`oc get route docker-registry -n default | grep docker-registry | awk {'print $2'}`
REGISTRY_URL=docker-registry.default.svc.cluster.local

rm -f prometheus34-deployment.yml
rm -f prometheus34-cm.yml
cp prometheus34-template.yml prometheus34-deployment.yml
cp prometheus34-cm-template.yml prometheus34-cm.yml

sed -i s/MASTER-URL/$MASTER_URL/g prometheus34-deployment.yml
sed -i s/MASTER-URL/$MASTER_URL/g prometheus34-cm.yml
sed -i s/MASTER-PORT/$MASTER_PORT/g prometheus34-deployment.yml
sed -i s/MASTER-PORT/$MASTER_PORT/g prometheus34-cm.yml
sed -i s/REGISTRY-URL/$REGISTRY_URL/g prometheus34-deployment.yml
sed -i s/REGISTRY-URL/$REGISTRY_URL/g prometheus34-cm.yml
sed -i s/REGISTRY-IP/$REGISTRY_IP/g prometheus34-deployment.yml

#I=0
#for ROUTE in `oc get route -n  default | grep router | awk {'print $2'}`; do

#    ROUTER_URL=`oc get route router -n default | grep router | awk {'print $2'}`

#    if [ "$I" -ne "0" ];then
#    ROUTER_URL=`echo $ROUTER_URL | sed s/router/router$I/g`
#    URL="- http://$ROUTER_URL/healthz"
#    echo $URL
#    sed -i "/ROUTER-URL/a \ \ \ \ \ \ \ \ \ \ \  ${URL}" prometheus34-deployment.yml
#    sed -i "/ROUTER-URL/a \ \ \ \ \ \ \ \ \ \ \  ${URL}" prometheus34-cm.yml
#    fi

#    ((I++))

#done

ROUTER_URL=`oc get route router -n default | grep router | awk {'print $2'}`
sed -i s/ROUTER-URL/$ROUTER_URL/g prometheus34-deployment.yml
sed -i s/ROUTER-URL/$ROUTER_URL/g prometheus34-cm.yml


##########################
# Set Registry IP for all Deployments
##########################

cp kube-state-metrics-template.yaml kube-state-metrics-deployment.yaml
#cp blackbox-exporter-template.yaml blackbox-exporter-deployment.yaml
cp grafana-template.yml grafana-deployment.yml
cp node-exporter-template.yml node-exporter-deployment.yml

sed -i s/REGISTRY-IP/$REGISTRY_IP/g kube-state-metrics-deployment.yaml
#sed -i s/REGISTRY-IP/$REGISTRY_IP/g blackbox-exporter-deployment.yaml
sed -i s/REGISTRY-IP/$REGISTRY_IP/g grafana-deployment.yml
sed -i s/REGISTRY-IP/$REGISTRY_IP/g node-exporter-deployment.yml

#########################
# Start the deployment
#########################

oc login -u system:admin
oc new-project prometheus
oc delete limitrange compute
oc label node --all prometheus=true
oc patch namespace prometheus -p '{"metadata": {"annotations": {"openshift.io/node-selector": ""}}}'

oadm policy add-scc-to-user anyuid -z default -n prometheus
oadm policy add-scc-to-user hostaccess -z prometheus-node-exporter
oadm policy add-scc-to-user hostnetwork -z prometheus-node-exporter
oadm policy add-scc-to-user hostnetwork -z prometheus
oadm policy add-cluster-role-to-user cluster-admin system:serviceaccount:prometheus:default
oadm policy add-cluster-role-to-user cluster-admin system:serviceaccount:prometheus:prometheus
 
oc create -f prometheus-is.yml -f prometheus34-deployment.yml -f grafana-deployment.yml -n prometheus

oc new-app prometheus -n prometheus
sleep 5
oc delete cm prometheus -n prometheus
oc create -f prometheus34-cm.yml -n prometheus
oc new-app grafana -n prometheus

#for file in `ls haproxy-*-*`; do
#oc create -f $file -n prometheus
#done
#oc create -f haproxy-svc.yml 

oc create -f node-exporter-deployment.yml -n prometheus
#oc create -f blackbox-exporter-deployment.yaml -f blackbox-svc.yml -n prometheus
oc create -f kube-state-metrics-service.yaml -f kube-state-metrics-deployment.yaml -n prometheus
