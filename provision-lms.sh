set -e
set -o pipefail
set -x

apps=( lms studio )

# Load database dumps for the largest databases to save time
./load-db.sh edxapp
./load-db.sh edxapp_csmh

# Bring edxapp containers online
for app in "${apps[@]}"; do
    docker-compose $DOCKER_COMPOSE_FILES up -d $app
done

docker-compose $DOCKER_COMPOSE_FILES exec -T lms bash -c 'source /edx/app/edxapp/edxapp_env && cd /edx/app/edxapp/edx-platform && NO_PYTHON_UNINSTALL=1 paver install_prereqs'

#Installing prereqs crashes the process
docker-compose restart lms

# Run edxapp migrations first since they are needed for the service users and OAuth clients
docker-compose $DOCKER_COMPOSE_FILES exec -T lms bash -c 'source /edx/app/edxapp/edxapp_env && cd /edx/app/edxapp/edx-platform && paver update_db --settings devstack_docker'

# Create a superuser for edxapp
docker-compose $DOCKER_COMPOSE_FILES exec -T lms bash -c 'source /edx/app/edxapp/edxapp_env && python /edx/app/edxapp/edx-platform/manage.py lms --settings=devstack_docker manage_user edx edx@example.com --superuser --staff'
docker-compose $DOCKER_COMPOSE_FILES exec -T lms bash -c 'source /edx/app/edxapp/edxapp_env && echo "from django.contrib.auth import get_user_model; User = get_user_model(); user = User.objects.get(username=\"edx\"); user.set_password(\"edx\"); user.save()" | python /edx/app/edxapp/edx-platform/manage.py lms shell  --settings=devstack_docker'

# Create an enterprise service user for edxapp and give them appropriate permissions
./enterprise/provision.sh

docker-compose $DOCKER_COMPOSE_FILES exec -T lms bash -c 'source /edx/app/edxapp/edxapp_env && python /edx/app/edxapp/edx-platform/manage.py lms --settings=devstack_docker add_organization PX PearsonX'
docker-compose $DOCKER_COMPOSE_FILES exec -T lms bash -c 'source /edx/app/edxapp/edxapp_env && python /edx/app/edxapp/edx-platform/manage.py lms --settings=devstack_docker add_organization demo Demo'

docker-compose $DOCKER_COMPOSE_FILES exec -T lms bash -c 'source /edx/app/edxapp/edxapp_env && python /edx/app/edxapp/edx-platform/manage.py lms create_or_update_site_configuration  --enabled localhost --configuration {\"course_org_filter\":[\"demo\"]\,\"COURSE_CATALOG_API_URL\":\"http://edx.devstack.discovery:18381/api/v1/\"}'
docker-compose $DOCKER_COMPOSE_FILES exec -T lms bash -c 'source /edx/app/edxapp/edxapp_env && python /edx/app/edxapp/edx-platform/manage.py lms create_or_update_site_configuration  --enabled lms.pearson.localhost:18000 --configuration {\"course_org_filter\":[\"PX\"]\,\"COURSE_CATALOG_API_URL\":\"http://discovery.pearson.localhost:18381/api/v1/\"}'
docker-compose $DOCKER_COMPOSE_FILES exec -T lms bash -c 'source /edx/app/edxapp/edxapp_env && python /edx/app/edxapp/edx-platform/manage.py lms create_or_update_site_configuration  --enabled lms.main.localhost:18000 --configuration {\"course_org_filter\":[\"PX\"\,\"demo\"]\,\"COURSE_CATALOG_API_URL\":\"http://discovery.main.localhost:18381/api/v1/\"}'

# Enable the LMS-E-Commerce integration
docker-compose $DOCKER_COMPOSE_FILES exec -T lms bash -c 'source /edx/app/edxapp/edxapp_env && python /edx/app/edxapp/edx-platform/manage.py lms --settings=devstack_docker configure_commerce'

# Create demo courses and users
docker-compose $DOCKER_COMPOSE_FILES exec -T lms bash -c 'source /edx/app/edxapp/edxapp_env && python /edx/app/edxapp/edx-platform/manage.py cms --settings=devstack_docker create_course split edx@example.com PX demo1 2020  "PX Course 1"'
docker-compose $DOCKER_COMPOSE_FILES exec -T lms bash -c 'source /edx/app/edxapp/edxapp_env && python /edx/app/edxapp/edx-platform/manage.py cms --settings=devstack_docker create_course split edx@example.com PX demo2 2020  "PX Course 2"'
docker-compose $DOCKER_COMPOSE_FILES exec -T lms bash -c 'source /edx/app/edxapp/edxapp_env && python /edx/app/edxapp/edx-platform/manage.py cms --settings=devstack_docker create_course split edx@example.com PX demo3 2020 "PX Course 3"'
docker-compose $DOCKER_COMPOSE_FILES exec -T lms bash -c 'source /edx/app/edxapp/edxapp_env && python /edx/app/edxapp/edx-platform/manage.py cms --settings=devstack_docker create_course split edx@example.com PX demo4 2020 "PX Course 4"'

docker-compose $DOCKER_COMPOSE_FILES exec -T lms bash -c 'source /edx/app/edxapp/edxapp_env && python /edx/app/edxapp/edx-platform/manage.py cms --settings=devstack_docker create_course split edx@example.com demo demo1 2020  "Demo Course 1"'
docker-compose $DOCKER_COMPOSE_FILES exec -T lms bash -c 'source /edx/app/edxapp/edxapp_env && python /edx/app/edxapp/edx-platform/manage.py cms --settings=devstack_docker create_course split edx@example.com demo demo2 2020  "Demo Course 2"'
docker-compose $DOCKER_COMPOSE_FILES exec -T lms bash -c 'source /edx/app/edxapp/edxapp_env && python /edx/app/edxapp/edx-platform/manage.py cms --settings=devstack_docker create_course split edx@example.com demo demo3 2020 "Demo Course 3"'
docker-compose $DOCKER_COMPOSE_FILES exec -T lms bash -c 'source /edx/app/edxapp/edxapp_env && python /edx/app/edxapp/edx-platform/manage.py cms --settings=devstack_docker create_course split edx@example.com demo demo4 2020 "Demo Course 4"'



docker-compose $DOCKER_COMPOSE_FILES exec -T lms bash -c '/edx/app/edx_ansible/venvs/edx_ansible/bin/ansible-playbook /edx/app/edx_ansible/edx_ansible/playbooks/demo.yml -v -c local -i "127.0.0.1," --extra-vars="COMMON_EDXAPP_SETTINGS=devstack_docker"'

# Fix missing vendor file by clearing the cache
docker-compose $DOCKER_COMPOSE_FILES exec -T lms bash -c 'rm /edx/app/edxapp/edx-platform/.prereqs_cache/Node_prereqs.sha1'

# Create static assets for both LMS and Studio
for app in "${apps[@]}"; do
    docker-compose $DOCKER_COMPOSE_FILES exec -T $app bash -c 'source /edx/app/edxapp/edxapp_env && cd /edx/app/edxapp/edx-platform && paver update_assets --settings devstack_docker'
done

# Provision a retirement service account user
./provision-retirement-user.sh retirement retirement_service_worker

# Add demo program
./programs/provision.sh lms
