___INFO___

{
  "type": "TAG",
  "id": "cvt_temp_public_id",
  "version": 1,
  "securityGroups": [],
  "displayName": "Domen test template",
  "brand": {
    "id": "brand_dummy",
    "displayName": ""
  },
  "description": "Domen test template",
  "containerContexts": [
    "SERVER"
  ]
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "RADIO",
    "name": "configuration",
    "displayName": "Configuration to use either BigQuery or Internal Transformer",
    "radioItems": [
      {
        "value": "big_query",
        "displayValue": "BigQuery"
      },
      {
        "value": "internal_transformer",
        "displayValue": "Internal Transformer"
      }
    ],
    "simpleValueType": true
  },
  {
    "type": "TEXT",
    "name": "bq_project_id",
    "displayName": "BigQuery Project ID",
    "simpleValueType": true,
    "enablingConditions": [
      {
        "paramName": "configuration",
        "paramValue": "big_query",
        "type": "EQUALS"
      }
    ]
  },
  {
    "type": "TEXT",
    "name": "bq_dataset_id",
    "displayName": "BigQuery Dataset ID",
    "simpleValueType": true,
    "enablingConditions": [
      {
        "paramName": "configuration",
        "paramValue": "big_query",
        "type": "EQUALS"
      }
    ]
  },
  {
    "type": "TEXT",
    "name": "bq_table_id",
    "displayName": "BigQuery Table ID",
    "simpleValueType": true,
    "enablingConditions": [
      {
        "paramName": "configuration",
        "paramValue": "big_query",
        "type": "EQUALS"
      }
    ]
  },
  {
    "type": "TEXT",
    "name": "internal_transformer_url",
    "displayName": "Internal Transformer URL",
    "simpleValueType": true,
    "enablingConditions": [
      {
        "paramName": "configuration",
        "paramValue": "internal_transformer",
        "type": "EQUALS"
      }
    ]
  },
  {
    "type": "TEXT",
    "name": "cookies",
    "displayName": "Cookies",
    "simpleValueType": true,
    "enablingConditions": [
      {
        "paramName": "configuration",
        "paramValue": "internal_transformer",
        "type": "EQUALS"
      }
    ]
  }
]


___SANDBOXED_JS_FOR_SERVER___

const Object = require('Object');
const addEventCallback = require('addEventCallback');
const getContainerVersion = require('getContainerVersion');
const BigQuery = require('BigQuery');
const getEventData = require('getEventData');
const getAllEventData = require('getAllEventData');
const getTimestampMillis = require('getTimestampMillis');
const sha256Sync = require('sha256Sync');
const getRequestQueryParameter = require('getRequestQueryParameter');
const log = require('logToConsole');
const getType = require('getType');
const getClientName = require('getClientName');
const parseUrl = require('parseUrl');
const getCookieValues = require('getCookieValues');
const sendHttpRequest = require('sendHttpRequest');
const JSON = require('JSON');

const allEventData = getAllEventData();

const eventDataParsed = [];

const ignoredParameters = ['client_hints', 'x-sst-system_properties'];

function getSpecialValue(type, value) {
  let isSpecialValue = null;
  if (type === 'array' || type === 'object' || type === 'function') {
    isSpecialValue = type;
  } else if (type === 'string') {
    const lcValue = value.toLowerCase();

    if (lcValue === 'undefined' || lcValue === 'null') {
      isSpecialValue = lcValue;
    } else if (lcValue === '') {
      isSpecialValue = 'empty_string';
    } else if (lcValue === 'eb045d78d273107348b0300c01d29b7552d622abbc6faf81b3ec55359aa9950c') {
      isSpecialValue = 'undefined';
    } else if (lcValue === '74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b') {
      isSpecialValue = 'null';
    } else if (lcValue === 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855') {
      isSpecialValue = 'empty_string';
    }
  }

  return isSpecialValue;
}

function recursiveParseEventData(eventData, prefix, inverseWeighting) {
  const type = getType(eventData);

  switch (type) {
    case 'null':
    case 'undefined':
      return;
    case 'object': {
      for (const row of Object.entries(eventData)) {
        const key = row[0];
        const value = row[1];

        if (key.indexOf('x-ga-') === 0 || ignoredParameters.indexOf(key) !== -1) {
          continue;
        }

        recursiveParseEventData(value, prefix ? prefix + '.' + key : key, inverseWeighting);
      }
      break;
    }
    case 'array': {
      // Only check value for first 2 items
      const slicedData = eventData.slice(0, 2);
      for (const value of slicedData) {
        recursiveParseEventData(value, prefix + '[]', (inverseWeighting ? inverseWeighting : 1) * slicedData.length);
      }

      break;
    }
    default: {
      let clusterValue = null;
      if (type === 'string' || type === 'number' || type === 'boolean') {
        clusterValue = sha256Sync((eventData + '').toLowerCase(), { outputEncoding: 'base64' }).slice(0, 1);
      }

      eventDataParsed.push({
        key: prefix,
        type: type,
        was_hashed: type === 'string' ? isSha256(eventData) : null,
        cluster_value: clusterValue,
        special_value: getSpecialValue(type, eventData),
        inverse_weighting: inverseWeighting,
      });
    }
  }
}

recursiveParseEventData(allEventData);

addEventCallback((containerId, eventData) => {
  const googleConsent = getRequestQueryParameter('gcs');
  const containerVersion = getContainerVersion();
  const hasRichSstSse = getType(getRequestQueryParameter('richsstsse')) !== 'undefined';

  const clientId = getEventData('client_id');
  const userAgent = getEventData('user_agent');

  // read data from template fields
  const internalTransformerUrl = data.internal_transformer_url;
  const configuration = data.configuration;
  const cookieNames = data.cookies.split(',');

  const cookies = {};
  for (const cookieName of cookieNames) {
    cookies[cookieName] = getCookieValues(cookieName)[0];
  }

  const row = {
    event_timestamp: getTimestampMillis() / 1000,
    event_name: getEventData('event_name'),
    client_id_hashed: clientId ? sha256Sync(clientId, { outputEncoding: 'base64' }) : null,
    user_agent: userAgent,
    user_agent_hashed: userAgent ? sha256Sync(userAgent, { outputEncoding: 'base64' }) : null,
    page_hostname: getEventData('page_hostname'),
    consent_settings: googleConsent,
    container_version: containerVersion.version,
    has_richsstsse: hasRichSstSse,
    tag: eventData.tags
      .filter((tag) => tag.exclude !== 'true')
      .map((tag) => ({
        id: tag.id,
        status: tag.status,
        execution_time: tag.executionTime,
      })),
    gtm_client_name: getClientName(),
    event_data: eventDataParsed,
    cookies: cookies,
  };

  if (getEventData('page_location')) {
    const parsedUrl = parseUrl(getEventData('page_location'));
    row.page_location_hostname = parsedUrl ? parsedUrl.hostname : null;
  }

  // insert to big query
  if (configuration === 'big_query') {
    
    const bigQueryConfig = {
      projectId: data.bq_project_id,
      datasetId: data.bq_dataset_id,
      tableId: data.bq_table_id,
    };
    
    BigQuery.insert(
      bigQueryConfig,
      [row],
      {},
      () => {
        log('BigQuery Success');
      },
      (errors) => {
        log('BigQuery Failure');
      }
    );

    data.gtmOnSuccess();
  }

  // call internal transformer
  else if (configuration === 'internal_transformer') {
    sendHttpRequest(
      internalTransformerUrl,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'GTM-Comprehensive-Capture/1.0',
        },
        timeout: 10000,
      },
      JSON.stringify(row)
    );
  }
});

data.gtmOnSuccess();

function isSha256(value) {
  return !!value.match('[a-fA-F0-9]{64}');
}


___SERVER_PERMISSIONS___

[
  {
    "instance": {
      "key": {
        "publicId": "read_event_metadata",
        "versionId": "1"
      },
      "param": []
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "read_request",
        "versionId": "1"
      },
      "param": [
        {
          "key": "queryParametersAllowed",
          "value": {
            "type": 8,
            "boolean": true
          }
        },
        {
          "key": "queryParameterAccess",
          "value": {
            "type": 1,
            "string": "any"
          }
        },
        {
          "key": "requestAccess",
          "value": {
            "type": 1,
            "string": "specific"
          }
        },
        {
          "key": "headerAccess",
          "value": {
            "type": 1,
            "string": "any"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "read_container_data",
        "versionId": "1"
      },
      "param": []
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "read_event_data",
        "versionId": "1"
      },
      "param": [
        {
          "key": "eventDataAccess",
          "value": {
            "type": 1,
            "string": "any"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "get_cookies",
        "versionId": "1"
      },
      "param": [
        {
          "key": "cookieAccess",
          "value": {
            "type": 1,
            "string": "any"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "send_http",
        "versionId": "1"
      },
      "param": [
        {
          "key": "allowedUrls",
          "value": {
            "type": 1,
            "string": "any"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "logging",
        "versionId": "1"
      },
      "param": [
        {
          "key": "environments",
          "value": {
            "type": 1,
            "string": "debug"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "access_bigquery",
        "versionId": "1"
      },
      "param": [
        {
          "key": "allowedTables",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "projectId"
                  },
                  {
                    "type": 1,
                    "string": "datasetId"
                  },
                  {
                    "type": 1,
                    "string": "tableId"
                  },
                  {
                    "type": 1,
                    "string": "operation"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "*"
                  },
                  {
                    "type": 1,
                    "string": "*"
                  },
                  {
                    "type": 1,
                    "string": "*"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  }
                ]
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  }
]


___TESTS___

scenarios: []


___NOTES___

Created on 12/10/2025, 10:19:34 AM


