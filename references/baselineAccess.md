# Basic-Example-Target-Access-Control

The example API specifies the minimal requirements for developing a new API that will be used for user provisioning from HelloID.

Card / Access control systems are uses to monitor, manage and grant access to particular areas of a building. Access is typically gained by using key cards, RFID cards, biometrics, QR codes etc...

> How this API is intended:
>
> We use roles to define which areas of a building a user is allowed to access. A role, literary can be anything. In our case, roles are defined by job titles. For instance, a janitor (floor cleaner, warden or steward) might need to access all areas in a building but only within a certain time window, where an office manager is only allowed to access specific areas.
>
> These roles will be applied to the access key that's assigned to the user.

The swagger interface can be found on: https://app.swaggerhub.com/apis-docs/ConnectorTeam/Basic-EXAMPLE-Target-API-Access-Control/2.0

## About

First and foremost, this API is merely an example. Your API (or the API you need to build) probably differs in more than one way. For example: Your actions might have different names, methods or inputs. And that's okay. We understand that no two APIs are alike.

Hopefully, the example API and documentation will provide some insight on what we expect and what we need in order to build a solid connector that will interact with your API.

If you have any questions or concerns, feel free to contact us. We are always happy to explain things more in depth.

## What's in the repo?

This repo contains the following:
- Source code for the 'EXAMPLE.API.Access.Control' API in the `src` folder.
- A swagger.yaml file with the api definitions that can be loaded in a swagger editor, so the definitions can be viewed without running the sample api.

## Table of contents
- [Basic-Example-Target-Access-Control](#basic-example-target-access-control)
  - [About](#about)
  - [What's in the repo?](#whats-in-the-repo)
  - [Table of contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
  - [Running the project](#running-the-project)
    - [MacOS](#macos)
    - [SQLite database](#sqlite-database)
    - [Swagger interface](#swagger-interface)
  - [About the API](#about-the-api)
    - [Role related actions](#role-related-actions)
      - [`GET: /api/Roles`](#get-apiroles)
    - [User related actions](#user-related-actions)
      - [`GET: /api/Users`](#get-apiusers)
      - [`POST: /api/Users`](#post-apiusers)
      - [`GET: /api/Users/ByEmployeeId/:employeeId`](#get-apiusersbyemployeeidemployeeid)
      - [`GET: /api/Users/:Id`](#get-apiusersid)
      - [`PATCH: /api/Users/:id`](#patch-apiusersid)
      - [`DEL: /api/Users/:id`](#del-apiusersid)
    - [Authorization related actions](#authorization-related-actions)
      - [`Get: /api/RoleAuthorizations`](#get-apiroleauthorizations)
      - [`POST: /api/RoleAuthorizations/Add`](#post-apiroleauthorizationsadd)
      - [`DEL: /api/RoleAuthorizations/Delete?roleId=:roleId&userId=:id`](#del-apiroleauthorizationsdeleteroleidroleiduseridid)
    - [AccessKey related actions](#accesskey-related-actions)
      - [`GET: /api/AccessKeyAssignments/:userid/AccessKeys`](#get-apiaccesskeyassignmentsuseridaccesskeys)
      - [`DEL: /api/AccessKeyAssignments/Delete?accessKeyId=:accessKeyId&userId=:userId`](#del-apiaccesskeyassignmentsdeleteaccesskeyidaccesskeyiduseriduserid)
      - [`PATCH /api/AccessKeys/:id`](#patch-apiaccesskeysid)
    - [Schemas](#schemas)
      - [User](#user)
      - [Role](#role)
      - [RoleAuthorization](#roleauthorization)
      - [AccessKey](#accesskey)
      - [AccessKeyAssignment](#accesskeyassignment)

## Prerequisites
- The .NET 8.0 SDK is required in order to use the API. Download from: https://dotnet.microsoft.com/en-us/download

## Running the project
Download the content of this repo directly using the zip file.

Or, from your favorite terminal:

1. Clone the repo. `gh repo clone Tools4everBV/Basic-Example-Target-API`.
2. Go to the `./src` folder.
3. Type: `dotnet build` or, to directly run the project: `dotnet run --urls https://localhost:5001`

> :exclamation: Make sure to change the URL and portnumber according to your environment.

### MacOS
When you are using MacOS, you might run into problems regarding keyChain.
To bypass this type: `dotnet run --urls https://localhost:5001 -p:UseAppHost=false`
see also: https://github.com/dotnet/sdk/issues/22544

### SQLite database
The project comes with a simple SQLite database. If you need a graphical interface to directly browse the database, go to: https://sqlitebrowser.org/dl/
Note that there are versions available for Windows, Linux and MacOS. (including Apple Silicon).

### Swagger interface
The API comes with a swagger interface located at: `{url}/swagger/index.html`

## About the API
The following actions are available:

### Role related actions
| HTTP Method | Endpoint                    | Description         |
| ----------- | --------------------------- | ------------------- |
| GET         | [/api/Roles](#get-apiroles) | Retrieves all roles |


#### `GET: /api/Roles`
Before we can assign a role to a user, we first need to retrieve all available roles. Then, we build out our business rules to, ultimately grant authorizations to users based on information coming from an HR source.

### User related actions
| HTTP Method | Endpoint                                                                   | Description               |
| ----------- | -------------------------------------------------------------------------- | ------------------------- |
| GET         | [/api/Users](#get-apiusers)                                                | Get all users
| POST        | [/api/Users](#post-apiusers)                                               | Add a user               |
| GET         | [/api/Users/ByEmployeeId/:employeeId](#get-apiusersbyemployeeidemployeeid) | Get a user by employeeId |
| GET         | [/api/Users/:Id](#get-apiusersid)                                          | Get a user by Id         |
| PATCH       | [/api/Users/:id](#patch-apiusersid)                                        | Update a user            |
| DEL         | [/api/Users/:id](#del-apiusersid)                                          | Delete a user            |

#### `GET: /api/Users`
We need to retrieve information about all users to support our import entitlement feature, enable reconciliation, and ultimately ensure proper [governance](#governance).

#### `POST: /api/Users`

Adds a new user account to the target system. The response must contain the internal database ID since this is the key we correlate on and will be used for consecutive requests to the target system. Therefore, the `id` field is enlisted in the user schema.

#### `GET: /api/Users/ByEmployeeId/:employeeId`

Before we add a user account to the target application, we need to validate if that user account exists.
Initially, the internal database ID is not known to us. Therefore, we prefer to validate this using the `EmployeeId` since this is unique and available in HelloID.

<em>Note that, retrieving all user accounts and do some type of lookup is -in most cases- not very well suited for HelloID and might cause performance issue's.</em>

> :exclamation: We only need to retrieve the user account using the `employeeId` in our initial create event. For all other events we will use the internal database ID. The `database ID` is the also key we correlate on in our create event.

#### `GET: /api/Users/:Id`

Before we update a particular user account, we need to validate if that user account still exists.

> :exclamation: Validating if the user account exists is an integral part in all our lifecycle events because the user account might be <em>unintentionally</em> deleted. In which case the lifecycle event will fail. </br></br> **For example:** when we want to enable the user account on the day the contract takes effect.

#### `PATCH: /api/Users/:id`

To update a user account we prefer to see an update call in the form of a patch. This means that we only update the values that have been changed.

> :exclamation: In the `Basic-EXAMPLE-Target-Access-Control-API-` the patch method is implemented using <a href="https://jsonpatch.com/">JSON Patch</a>. Note that this might not have to be the best solution for your application.

#### `DEL: /api/Users/:id`

This action does not require a response. A [204 No Content] is sufficient.

### Authorization related actions

| HTTP Method | Endpoint | Description |
| --- | --- |--- |
| GET | [/api/RoleAuthorisations](#get-roleauthorizations) | get all role authorizations |
| POST | [/api/RoleAuthorizations/Add](#post-apiusersauthorizationsadd) | Add a new authorization for a specific user |
| DEL | [/api/RoleAuthorizations/Delete?roleId=:roleId&userId=:userId](#del-apiusersauthorizationsdeleteroleidroleiduseridid) | Deletes an authorization for a specific user |

#### `Get: /api/RoleAuthorizations`
We need to retrieve information about all authorizations (granted to all users) to support our import entitlement feature, enable reconciliation, and ultimately ensure proper [governance](#governance).

#### `POST: /api/RoleAuthorizations/Add`

We will use this action when an authorization is granted to a user. Since we do not store the result in HelloID, this action does not require a response.

#### `DEL: /api/RoleAuthorizations/Delete?roleId=:roleId&userId=:id`

We will use this action when an authorization is revoked from a user. This action does not require a response. A [204 No Content] is sufficient.

### AccessKey related actions

| HTTP Method | Endpoint | Description |
| --- | --- |--- |
| GET   | [/api/AccessKeyAssignments/:userid/AccessKeys](#get-apiaccesskeyassignmentsuseridaccesskeys) | Get a list of assigned access keys |
| DEL   | [/api/AccessKeyAssignments/Delete?accessKeyId=:accessKeyId&userId=:userId](#del-apiusersaccesskeysdeleteaccesskeyidaccesskeyiduseriduserid) | Deletes an accessKey (by Id) for a specific user |
| PATCH | [/api/AccessKeys/:id] (#patch-apiaccesskeysid) | Updates properties of an access key |

#### `GET: /api/AccessKeyAssignments/:userid/AccessKeys`

We will use this action to get a current list of accessKeys assigned to a user.

> When the user account gets disabled or deleted, these accessKeys will be revoked from the user.

#### `DEL: /api/AccessKeyAssignments/Delete?accessKeyId=:accessKeyId&userId=:userId`

We will use this action when an accessKey is revoked from a user. This action does not require a response. A [204 No Content] is sufficient.

#### `PATCH /api/AccessKeys/:id`

We will use this action to update an AccessKey. This action does not require a response. A [204 No Content] is sufficient.

### Schemas

#### User

The user schema contains all the parameters we expect to be present in an application. Your application / user schema might have different names for parameters, or far more parameters than enlisted in this schema.

For example: A `PhoneNumber` for two-factor authentication or a more complex multi-layered schema.

> :exclamation: The user schema contains the bare minimum we need in order to build a solid connector.

| Parameter | Description | Required | Type |
|--- |--- | --- | --- |
| Id | This is the internal / database Id.</br> Typically, this value will be set by the application | - | <em>int</em>
| Active | Defines if the user is active or not. We will update this value when a user is enabled or disabled.</br></br> When we initially create a user, we prefer to create that user in a `disabled state`. On the day the contract takes effect the user account will be enabled. | True | <em>bool</em> |
| [EmployeeId](#get-apiusersbyemployeeidemployeeid) | The EmployeeId or ExternalId of the user. | True | <em>string</em> |
| FirstName | - | True | <em>string</em> |
| LastName | - | True | <em>string</em> |
| Email | - | True | <em>string</em> |

#### Role

| Parameter | Description | Required | Type |
|--- |--- | --- | --- |
| Id | This is the internal / database Id.</br> Typically, this value will be set by the application | - | <em>int</em> |
| DisplayName | The DisplayName of the role | True | <em>string</em> |

#### RoleAuthorization

| Parameter | Description | Required | Type |
|--- |--- | --- | --- |
| Id | This is the internal / database Id.</br> Typically, this value will be set by the application | - | <em>int</em> |
| RoleId | The Id of the role. | True | <em>int</em> |
| UserId | The Id of the user. | True | <em>int</em> |

#### AccessKey

| Parameter | Description | Required | Type |
|--- |--- | --- | --- |
| Id | This is the internal / database Id.</br> Typically, this value will be set by the application | - | <em>int</em> |
| DisplayName | The DisplayName of the AccessKey | - | <em>string</em> |
| Type | The Type of the AccessKey<br> For example; 'visitor' or 'employee' | - | <em>string</em> |
| IsActive | The state of the AccessKey | - | <em>string</em> |

#### AccessKeyAssignment

| Parameter | Description | Required | Type |
|--- |--- | --- | --- |
| Id | This is the internal / database Id.</br> Typically, this value will be set by the application | - | <em>int</em> |
| AccessKeyId | The Id of the Access key. | True | <em>int</em> |
| UserId | The Id of the user. | True | <em>int</em> |
