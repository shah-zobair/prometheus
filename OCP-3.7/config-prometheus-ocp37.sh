#!/bin/bash


########################################################
# This script will prepare all the deployment files for deploying prometheus.

# Make sure you have pushed following images to Internal OpenShift registry and into openshift repositry.

# prometheus
# kube-state-metrics
# prometheus-node-exporter
# grafana-ocp
# haproxy-exporter

#Example:
#docker-registry.default.svc:5000/openshift/kube-state-metrics                  latest              49dfd221b31d        7 weeks ago         242.8 MB
#docker-registry.default.svc:5000/openshift/prometheus-node-exporter            latest              9971c9a78974        10 weeks ago        209.1 MB
#docker-registry.default.svc:5000/openshift/grafana-ocp			  latest
#docker-registry.default.svc:5000/openshift/haproxy-exporter			  latest


#########################################################
#########################################################

IMAGE_URL="docker-registry.default.svc:5000"
IMAGE_TAG="v3.7"

PROMETHEUS_IMAGE_TAG=$IMAGE_TAG
KUBE_STATE_IMAGE_TAG=$IMAGE_TAG
NODE_EXPORTER_IMAGE_TAG=$IMAGE_TAG
GRAFANA_IMAGE_TAG=$IMAGE_TAG
HAPROXY_EXP_IMAGE_TAG=$IMAGE_TAG

#export KUBECONFIG=/etc/origin/master/admin.kubeconfig; oc login -u system:admin > /dev/null; oc whoami

oc login -u system:admin

##########################
# Expose routes for Routers
##########################

for DC in `oc get dc -n default | grep router | awk {'print $1'}`;do
    oc env dc $DC ROUTER_METRICS_TYPE-
done

for SERVICE in `oc get svc -n default | grep router | awk {'print $1'}`; do
    PORT=`oc get svc $SERVICE -n default| grep -o 19..`
    oc expose service $SERVICE --port=$PORT -n default
    #echo $SERVICE $PORT
    
done

echo "PLEASE ALLOW TCP/1936 on all INFRA NODES"

##########################
# Prepare haproxy-exporter template file for each router pod
##########################

REGISTRY_IP=docker-registry.default.svc.cluster.local
rm -f haproxy-*-dc.yml

for SERVICE in `oc get svc -n default | grep router | awk {'print $1'}`; do
    DC=$SERVICE
    ROUTER_PASSWORD=`oc describe dc $DC -n default | grep STATS_PASSWORD | awk {'print $2'}`
    ROUTER_SVC_FQDN=$SERVICE".default.svc.cluster.local"
    ROUTER_STAT_PORT=1936

    cp haproxy-template.yml haproxy-$DC-dc.yml
    sed -i s/haproxy-exporter-template/haproxy-exporter-$DC/g haproxy-$DC-dc.yml
    sed -i s/REGISTRY-IP/$IMAGE_URL/g haproxy-$DC-dc.yml
    sed -i s/ROUTER-IP/$ROUTER_SVC_FQDN/g haproxy-$DC-dc.yml
    sed -i s/ROUTER-PORT/$ROUTER_STAT_PORT/g haproxy-$DC-dc.yml
    sed -i s/ROUTER-PASS/$ROUTER_PASSWORD/g haproxy-$DC-dc.yml
    sed -i s/IMAGE-TAG/$HAPROXY_EXP_IMAGE_TAG/g haproxy-$DC-dc.yml
done


##########################
# Set IMAGE URL AND TAG for all Deployments
##########################

rm -f prometheus37-deployment.yml
rm -f prometheus37-cm.yml
rm -f kube-state-metrics-deployment.yaml
rm -f grafana-deployment.yml
rm -f node-exporter-deployment.yml
rm -f prometheus-is.yml
#rm -f haproxy-*-dc.yml

cp prometheus37-template.yml prometheus37-deployment.yml
cp prometheus37-cm-template.yml prometheus37-cm.yml

cp kube-state-metrics-template.yaml kube-state-metrics-deployment.yaml
cp grafana-template.yml grafana-deployment.yml
cp node-exporter-template.yml node-exporter-deployment.yml
cp prometheus-is-template.yml prometheus-is.yml



sed -i s/REGISTRY-IP/$IMAGE_URL/g kube-state-metrics-deployment.yaml
sed -i s/REGISTRY-IP/$IMAGE_URL/g grafana-deployment.yml
sed -i s/REGISTRY-IP/$IMAGE_URL/g node-exporter-deployment.yml
sed -i s/REGISTRY-IP/$IMAGE_URL/g prometheus37-deployment.yml

sed -i s/IMAGE-TAG/$KUBE_STATE_IMAGE_TAG/g kube-state-metrics-deployment.yaml
sed -i s/IMAGE-TAG/$GRAFANA_IMAGE_TAG/g grafana-deployment.yml
sed -i s/IMAGE-TAG/$NODE_EXPORTER_IMAGE_TAG/g node-exporter-deployment.yml
sed -i s/IMAGE-TAG/$PROMETHEUS_IMAGE_TAG/g prometheus37-deployment.yml

sed -i s/HAPROXY-EXP-IMAGE-TAG/$HAPROXY_EXP_IMAGE_TAG/g prometheus-is.yml
sed -i s/KUBE-STATE-IMAGE-TAG/$KUBE_STATE_IMAGE_TAG/g prometheus-is.yml
sed -i s/GRAFANA-IMAGE-TAG/$GRAFANA_IMAGE_TAG/g prometheus-is.yml
sed -i s/NODE-EXPORTER-IMAGE-TAG/$NODE_EXPORTER_IMAGE_TAG/g prometheus-is.yml
sed -i s/PROMETHEUS-IMAGE-TAG/$PROMETHEUS_IMAGE_TAG/g prometheus-is.yml

#########################
# Start the deployment
#########################

oc login -u system:admin
oc new-project prometheus
oc label node --all prometheus=true
oc patch namespace prometheus -p '{"metadata": {"annotations": {"openshift.io/node-selector": ""}}}'

oadm policy add-scc-to-user anyuid -z default -n prometheus
oadm policy add-scc-to-user hostaccess -z prometheus-node-exporter
oadm policy add-scc-to-user hostnetwork -z prometheus-node-exporter
oadm policy add-scc-to-user hostnetwork -z prometheus
oadm policy add-cluster-role-to-user cluster-admin system:serviceaccount:prometheus:default
oadm policy add-cluster-role-to-user cluster-admin system:serviceaccount:prometheus:prometheus
 
oc create -f prometheus-is.yml -f prometheus37-deployment.yml -f grafana-deployment.yml -n prometheus

oc new-app prometheus -n prometheus
sleep 5
oc delete cm prometheus -n prometheus
oc create -f prometheus37-cm.yml -n prometheus
oc new-app grafana -n prometheus

for file in `ls haproxy-*-dc.yml`; do
oc create -f $file -n prometheus
done
oc create -f haproxy-svc.yml 

oc create -f node-exporter-deployment.yml -n prometheus
oc create -f blackbox-exporter-deployment.yaml -f blackbox-svc.yml -n prometheus
oc create -f kube-state-metrics-service.yaml -f kube-state-metrics-deployment.yaml -n prometheus
