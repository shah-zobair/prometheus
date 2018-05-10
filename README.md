# Prometheus Deployment for OpenShift 
Prometheus to monitor OpenShift cluster

This guide will deploy Prometheus and Grafana to monitor OpenShift cluster with the help of prometheus-node-exporter, kube-state-metrics, haproxy-exporter and blackbox-exporter. This is mainly developed for OpenShift version 3.6 and earlier, latest version of OCP has Red Hat supported playbooks to deploy all components out of the box.

We will deploy all the components using a shell script. The script will create application templates based on OpenShift environment and will deploy each component. It will create a project named “prometheus”. Whoever running this script, needs cluster-admin privilege and also system:admin access. Some components require cluster-admin privilege and also need to be run as privileged pod.

Download and Push all the required images to OpenShift internal registry:
```
docker pull docker.io/openshift/prometheus:latest
docker pull docker.io/openshift/prometheus-alertmanager:latest
docker pull registry.access.redhat.com/openshift3/prometheus-alert-buffer:latest
docker pull docker.io/mrsiano/grafana-ocp:latest
docker pull docker.io/openshift/kube-state-metrics:latest
docker pull docker.io/szobair/blackbox-exporter:latest
docker pull registry.access.redhat.com/openshift3/prometheus-node-exporter:latest
docker pull docker.io/prom/haproxy-exporter:latest
```
```
docker tag docker.io/openshift/prometheus docker-registry.default.svc:5000/openshift/prometheus:v3.6

docker tag docker.io/openshift/prometheus-alertmanager docker-registry.default.svc:5000/openshift/prometheus-alertmanager:v3.6

docker tag registry.access.redhat.com/openshift3/prometheus-alert-buffer docker-registry.default.svc:5000/openshift/prometheus-alert-buffer:v3.6

docker tag docker.io/mrsiano/grafana-ocp docker-registry.default.svc:5000/openshift/grafana-ocp

docker tag docker.io/openshift/kube-state-metrics docker-registry.default.svc:5000/openshift/kube-state-metrics

docker tag docker.io/szobair/blackbox-exporter docker-registry.default.svc:5000/openshift/blackbox-exporter

docker tag registry.access.redhat.com/openshift3/prometheus-node-exporter docker-registry.default.svc:5000/openshift/prometheus-node-exporter:v3.6

docker tag docker.io/prom/haproxy-exporter docker-registry.default.svc:5000/openshift/haproxy-exporter
```
```
oc login -u <user-name>
docker login -u <user-name> -p $(oc whoami -t) docker-registry.default.svc:5000
```
```
docker push docker-registry.default.svc:5000/openshift/prometheus:v3.6
docker push docker-registry.default.svc:5000/openshift/prometheus-alertmanager:v3.6
docker push docker-registry.default.svc:5000/openshift/prometheus-alert-buffer:v3.6
docker push docker-registry.default.svc:5000/openshift/grafana-ocp
docker push docker-registry.default.svc:5000/openshift/kube-state-metrics
docker push docker-registry.default.svc:5000/openshift/blackbox-exporter
docker push docker-registry.default.svc:5000/openshift/prometheus-node-exporter:v3.6
docker push docker-registry.default.svc:5000/openshift/haproxy-exporter
```
Clone the repository for the script and template files:
```
git clone https://github.com/shah-zobair/prometheus.git
```

Deploy prometheus and all other components:
```
cd prometheus
./config-prometheus.sh
```

**Prometheus data source in Grafana**

Once all the components are deployed and running, browse grafana web-portal and add prometheus add data source:
* Log into Grafana using the Route created by the Template.
* On the Home Dashboard click Add data source.
* Use the following values for the datasource Config: ** Name: prometheus ** Type: prometheus ** Url: http://prometheus:9090 ** Access: proxy
Click Add
*Click Save & Test. You should see a message that the data source is working.


**Create Grafana dashboards**

Repeat the following steps for each of the .json file in the grafana-dashboard directory:
* In Grafana select the Icon on the top left and then select Dashboards / Import.
* Either copy/paste the contents of the JSON File (make sure to keep the correct formatting) or click the Upload .json File button selecting the .json file.
* In the next dialog enter a name for the dashboard (name of the json file) and select the previously created datasource prometheus for Prometheus.
* Click Import

**Prometheus Persistent Volume**

The template does not configure persistent volume for prometheus-data. Consider adding a PV or hostPath volume to make the data persistent.

Few examples below:
NFS Mount:
```
oc volume deploymentconfigs/prometheus --add --overwrite --name=prometheus-data --mount-path=/prometheus --source='{"nfs": { "server": "nfs.example.com", "path": "/opt/nfs/prometheus"}}'
```
GlusterFS Mount:
```
oc volume deploymentconfigs/prometheus --add --overwrite --name=prometheus-data --mount-path=/prometheus --source='{"glusterfs": { "endpoints": "glusterfs-cluster", "path": "/prometheus"}}'
```
By PVC:
```
oc volume dc/prometheus --add --overwrite --name=prometheus-data --type=persistentVolumeClaim --claim-name=prometheus-pvc
```

**Firewall rules**

On all nodes:
```
iptables -A OS_FIREWALL_ALLOW -p tcp -m tcp --dport 9100 -j ACCEPT
sed -i '/COMMIT/i -A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 9100 -j ACCEPT' /etc/sysconfig/iptables
```

On Infra nodes:
```
iptables -A OS_FIREWALL_ALLOW -p tcp -m tcp --dport 1936 -j ACCEPT
sed -i '/COMMIT/i -A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 1936 -j ACCEPT' /etc/sysconfig/iptables
```

