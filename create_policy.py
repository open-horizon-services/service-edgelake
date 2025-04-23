import argparse
import ast
import json
import os

try:
    FileNotFoundError
except NameError:
    FileNotFoundError = IOError

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
IGNORE_LIST = ["REMOTE_CLI", "ENABLE_NEBULA", "NEBULA_NEW_KEYS", "IS_LIGHTHOUSE", "CIDR_OVERLAY_ADDRESS",
               "LIGHTHOUSE_IP", "LIGHTHOUSE_NODE_IP"]

# read content from deployment.policy.json if exists
if os.path.isfile(FILE_PATH):
    with open(FILE_PATH, 'r') as f:
        BASE_POLICY = json.load(f)


def read_file(file_path):
    """
    Given (dotenv) file - read its content and convert to be used for BASE_POLICY
    At the end of the day, code returns a list of userInput objects
    :sample userInput object:
    {
      "name": "NODE_TYPE",
      "label": "EdgeLake starts TCP and REST connection protocols",
      "type": "string",
      "value": "generic"
    }
    :global:
        IGNORE_LIST:list - list of env params used with Docker that can be ignored with OpenHorizon
    :args:
        file_path:str - file path
    :params:
        user_input:list - generated list of userInput objects
        key, value - extracted key / value pair from dotenv file(s)
        val_type:str - data type for value
    :return:
        user_input
    """
    user_input = []
    key = ""
    description = ""
    value = ""
    val_type = ""

    with open(file_path, 'r') as fname:
        for line in fname:
            if line.strip() == "": # ignore if empty line
                continue
            elif line.startswith('#'): # add description
                description = line.split('#')[-1].strip()
            elif not line.startswith('#'): # add params
                key, value = line.split("=", 1)
                key = key.strip()
                if key not in IGNORE_LIST:
                    value = value.strip()
                    try:
                        value = ast.literal_eval(value)
                    except Exception:
                        pass

                    if isinstance(value, str) and value.lower() in ['true', 'false']:
                        value = True if value.lower() == 'true' else False

                    if key and value and description and val_type and value != '""': # set params + description in userInput list
                        user_input.append({
                            "name": key,
                            "label": description,
                            "type": 'bool' if isinstance(value, bool) else 'int' if isinstance(value, int) else 'string',
                            "value": value if key != "DISABLE_CLI" else True
                        })
                        key = ""
                        description = ""
                        value = ""
                        val_type = ""

    return user_input


def main():
    """
    The following script converts EdgeLake configuration file from dotenv format to OpenHorizon / YAML format
    :positional arguments:
      version      EdgeLake version
      config_file  config file
    :options:
      -h, --help   show this help message and exit
    :global:
        BASE_POLICY:dict - Base policy for generating deployment.policy.json
        FILE_PATH:str - full path for deployment.policy.json
    :params:
        full_path:str - full path for config file
    """
    global BASE_POLICY
    parse = argparse.ArgumentParser()
    parse.add_argument('version', type=str, default="latest", help="EdgeLake version")
    parse.add_argument('config_file', type=str, default=None, help='config file')
    args = parse.parse_args()

    full_path = os.path.expanduser(os.path.expandvars(args.config_file))
    if not os.path.isfile(full_path):
        raise FileNotFoundError(full_path)

    BASE_POLICY['service']['serviceVersions'][0]['version'] = args.version
    BASE_POLICY['userInput'][0]['inputs'] = read_file(file_path=full_path)

    with open(FILE_PATH, 'w') as fname:
        json.dump(BASE_POLICY, fname, indent=2, ensure_ascii=False)


if __name__ == '__main__':
    main()
