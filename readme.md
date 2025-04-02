
# HelloID-Conn-Prov-Source-XTrend


| :information_source: Information                                                                                                                                                                                                                                                                                                                                                       |
| :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as clientID, clientSecret, tenantId, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements. |

<p align="center">
  <img src="">
</p>

## Table of contents

- [HelloID-Conn-Prov-Source-X-Trend](#HelloID-Conn-Prov-Source-X-Trend)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
    - [Endpoints](#endpoints)
  - [Getting started](#getting-started)
    - [Connection settings](#connection-settings)
    - [Remarks](#remarks)
      - [Logic in-depth](#logic-in-depth)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Introduction

_HelloID-Conn-Prov-Source-X-Trend_ is a _source_ connector. The purpose of this connector is to import _persons_ and their _employmentData_.

### Endpoints

Currently the following endpoints are being used..

| Endpoints                    |
| ---------------------------- |
| /{tenant_id}/oauth2/token    |
| /data/HelloIdDatas           |

## Getting started

### Connection settings

The following settings are required to connect to the API.

| Setting    | Description                                                                            | Mandatory |
| ---------- | -------------------------------------------------------------------------------------- | --------- |
| ClientId     | The client id to connect to the API                                                       | Yes       |
| ClientSecret     | The client secret to connect to the API                                                       | Yes       |
| TenantId    | The tenant id to connect to the API                                                                     | Yes       |
| BaseUrl    | The URL to the API                                                                     | Yes       |
| TokenBaseUrl    | The URL to retrieve an access token                                                                    | Yes       |
| HistoricalDays | - The number of days in the past from which the shifts will be imported.<br> - Will be converted to a `[DateTime]` object containing the _current date_ __minus__ the number of days specified. | Yes       |
| FutureDays | - The number of days in the future from which the shifts will be imported.<br> - Will be converted to a `[DateTime]` object containing the _current date_ __plus__ the number of days specified. | Yes       |

### Remarks
- The API returns an object for each employment, including the associated person’s data. If a person has multiple employments, the connector uses the person data from the longest active employment.

- The API doesn't return an error when the TokenBaseUrl is invalid.

- All employees are imported based on a filter with x amount of days in the past and X amount of days in the future.

- Since HelloID lacks a unique field for contracts, the externalId is composed of dataAreaId, PersonnelNumber, and StartDate. If this is insufficient, consider adding another property.

## Getting help

> ℹ️ _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/hc/en-us/articles/360012557600-Configure-a-custom-PowerShell-source-system) pages_

> ℹ️ _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com/forum/helloid-connectors/provisioning/5340-helloid-provisioning-source-x-trend)_

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/

