## Usar el cluster de persistencia
export SSHPASS='BdPxwPwm*w9ncE59'
## Nos conectamos a un cluester en especifico 
## ssh: Comando para iniciar una sesión SSH, devops@192.168.25.102: Usuario devops conectándose al servidor con IP 192.168.25.102
sshpass -e ssh -o StrictHostKeyChecking=no -v devops@192.168.25.102

## Validar que se encuentra en el cluster de persistencia 
## Listar los pods en todos los namespaces 
microk8s kubectl get pods --all-namespaces
## Le debe salir los pods del kafka 
microk8s kubectl get pods -n d4m-debezium-kafka
## microk8s → Indica que estás usando MicroK8s, una versión ligera de Kubernetes.
## kubectl get pods → Lista los Pods que están corriendo en Kubernetes
## -n d4m-debezium-kafka → Filtra los Pods dentro del Namespace llamado d4m-debezium-kafka

## APARTIR DE ESTA LINEA HAREMOS CONFIGURACIONES, PARA SE CREE EL POD KAFKA-DEBEZIUM-POSTGRESS CORRECTAMENTE
# PLAIN
#Eliminar el fichero plain.properties existente
rm plain.properties
## variables de entorno con los nombres del cluster y usuario
export KAFKA_CLUSTER_NAME=d4m-debezium-kafka-cluster
export KAFKA_USER_NAME=d4m-debezium-admin

## Creacion del fichero plain.properties (este fichero contiene toda la configuracion que realizo el Debezium al momento de conectarse con Postgress y kafka)
touch plain.properties
# Extrae el password del kafka
KAFKA_PASSWORD=$(microk8s kubectl get secret ${KAFKA_USER_NAME}  -n d4m-debezium-kafka -o jsonpath='{.data.password}' | base64 -d)
# se ve el password del kafka
echo ${KAFKA_PASSWORD}
# Creacion del fichero plain.properties con lo necesario para conectarse al kafka
echo """security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username=\"${KAFKA_USER_NAME}\" password=\"${KAFKA_PASSWORD}\";""" | tee plain.properties


## Una vez creado el fichero

#######################
## PRODUCER PLAIN
## PASOS PARA CREAR UN POD
## Verificar si el Pod existe
microk8s kubectl get pods -n d4m-debezium-kafka | grep kafka-producer
## Borrar el pod si es que existe
microk8s kubectl -n d4m-debezium-kafka delete pod/kafka-producer
## Creacion del pod kafka-producer
microk8s kubectl -n d4m-debezium-kafka run kafka-producer -ti --image=registry-dev.ms4m.com/kafka:0.42.0-kafka-3.7.1 --attach=false --restart=Never
## Copiar el fichero plain.properties dentro del contenedor de kafka-producer
microk8s kubectl cp --namespace d4m-debezium-kafka plain.properties kafka-producer:/tmp/plain.properties
## Acceder a la terminal del contenedor de kafka
microk8s kubectl attach -n d4m-debezium-kafka kafka-producer -ti

######################
## ACCEDER AL POD EN ESPECIFICO
## Ejecutar o ingresar directamente al pod de Kafka
## microk8s kubectl exec -it kafka-bryan -n d4m-debezium-kafka -- /bin/bash

## Podemos verificar tambien los servicios para extraer el IP y el puerto para ejecutar dentro del Pod
## Ejecutar este comando fuera del POD
#microk8s kubectl get svc -n d4m-debezium-kafka
#microk8s kubectl describe svc d4m-debezium-kafka-cluster-kafka-external-bootstrap -n d4m-debezium-kafka

## LISTAR LOS TOPICOS QUE TENEMOS EN EL POD ()

./bin/kafka-topics.sh \
  --bootstrap-server kafka-debezium-qa-d4m.ms4m.com:9094 \
  --list \
  --command-config /tmp/plain.properties \
| xargs -I {} bash -c "echo 'Tópico: {}'; ./bin/kafka-get-offsets.sh --bootstrap-server kafka-debezium-qa-d4m.ms4m.com:9094 --command-config /tmp/plain.properties --topic {} --time -1"


#####################################
## ESCUCHAR LOS EVENTOS DEL DEBEZIUM , Y MANDARLOS A EL TOPICO DE KAFKA
## Indica que el consumidor debe leer todos los mensajes desde el inicio del tópico (offset 0
./bin/kafka-console-consumer.sh \
  --bootstrap-server kafka-debezium-qa-d4m.ms4m.com:9094 \
  --topic ControlSenseDB.public.tp_cargadescarga \
  --from-beginning \
  --consumer.config /tmp/plain.properties

## Indica que el consumidor debe leer solo lea los mensajes nuevos (es decir, los que lleguen después de que inicies el consumidor)
./bin/kafka-console-consumer.sh \
  --bootstrap-server kafka-debezium-qa-d4m.ms4m.com:9094 \
  --topic ControlSenseDB.public.tp_cargadescarga \
  --consumer.config /tmp/plain.properties

## Purgar el contenedor 
microk8s kubectl -n d4m-debezium-kafka delete pod/kafka-producer
