import argparse
import ast
import json
import os

ROOT_DIR = os.path.expanduser(os.path.expandvars(__file__)).split("create_policy.py")[0]
FILE_PATH = os.path.join(ROOT_DIR, 'deployment.policy.json')
BASE_POLICY = {
    "label": "${SERVICE_NAME} Deployment Policy",
    "description": "Policy to auto deploy ${SERVICE_NAME}",
    "service": {
        "name": "${SERVICE_NAME}",
        "org": "${HZN_ORG_ID}",
        "arch": "*",
        "serviceVersions": [{
            "version": "",
            "priority": {
                "priority_value": 1,
                "retries": 2,
                "retry_durations": 1800
            }
        }]
    },
    "properties": [],
    "constraints": [
         "purpose == edgelake",
         "openhorizon.allowPrivileged == true"
    ],
    "userInput": [{
        "serviceOrgid": "${HZN_ORG_ID}",
        "serviceUrl": "${SERVICE_NAME}",
        "serviceVersionRange": "[0.0.0,INFINITY)",
        "inputs": []
    }]
}

if os.path.isfile(FILE_PATH):
    with open(FILE_PATH, 'r') as f:
        BASE_POLICY = json.load(f)


def read_file(file_path):
    user_input = []
    key = ""
    description = ""
    value = ""
    val_type = ""

    with open(file_path, 'r') as f:
        for line in f.read().split("\n"):
            if line != "" and line.startswith('#') and description != "Run code in debug mode":
                description = line.split('#')[-1].strip()
            elif line != "" and not line.startswith('#'):
                key, value = line.split("=")
                key = key.strip()
                value = value.strip()
                val_type = 'string'
                try:
                    value = ast.literal_eval(value)
                except:
                    pass
                finally:
                    if value in ['true', 'false']:
                        val_type = 'bool'
                        value = bool(value)
                    elif isinstance(value, int):
                        val_type = 'int'

            if key != "REMOTE_CLI":
                if key and value and description and val_type and value != '""':
                    user_input.append({
                        "name": key,
                        "label": description,
                        "type":val_type,
                        "value": value if key != "DISABLE_CLI" else True
                    })
                    key = ""
                    description = ""
                    value = ""
                    val_type = ""

    return user_input


def main():
    global BASE_POLICY
    parse = argparse.ArgumentParser()
    parse.add_argument('version', type=str, default="latest", help="EdgeLake version")
    parse.add_argument('config_file', type=str, default=None, help='config file')
    args = parse.parse_args()

    BASE_POLICY['service']['serviceVersions'][0]['version'] = args.version
    full_path = os.path.expanduser(os.path.expandvars(args.config_file))
    if not os.path.isfile(full_path):
        raise FileNotFoundError(full_path)
    BASE_POLICY['userInput'][0]['inputs'] = read_file(file_path=full_path)

    with open(FILE_PATH, 'w') as f:
        json.dump(BASE_POLICY, f, indent=2)

if __name__ == '__main__':
    main()
