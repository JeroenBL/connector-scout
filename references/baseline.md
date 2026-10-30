# Basic-Example-Target-API

The example API specifies the minimal requirements for developing a new API that will be used for user provisioning from HelloID.

> [!NOTE]
> The swagger interface can be found on: https://app.swaggerhub.com/apis-docs/ConnectorTeam/Basic-EXAMPLE-Target-API/1.0

## About

First and foremost, this API is merely an example. Your API (or the API you need to build) probably differs in more than one way. For example: Your actions might have different names, methods or inputs. And that's okay. We understand that no two APIs are alike.

Hopefully, the example API and documentation will provide some insight on what we expect and what we need in order to build a solid connector that will interact with your API.

If you have any questions or concerns, feel free to contact us. We are always happy to explain things more in depth.

## What's in the repo?

This repo contains the following:

- Source code for the 'Basic-EXAMPLE-Target-API' in the `src` folder.
- Postman collection with all API calls and examples in the `assets` folder.

## Table of contents

- [Basic-Example-Target-API](#basic-example-target-api)
  - [About](#about)
  - [What's in the repo?](#whats-in-the-repo)
  - [Table of contents](#table-of-contents)
  - [Running the project](#running-the-project)
  - [Settings](#settings)
      - [Logging](#logging)
      - [Kestrel](#kestrel)
      - [ApplicationSettings](#applicationsettings)
    - [SQLite database](#sqlite-database)
    - [Web interface](#web-interface)
  - [About the API](#about-the-api)
    - [Authentication](#authentication)
      - [`POST: /api/auth/token`](#post-apiauthtoken)
    - [User related actions](#user-related-actions)
      - [`GET: /api/users`](#get-apiusers)
      - [`POST: /api/users`](#post-apiusers)
      - [`GET: /api/users/employeeid/:employeeId`](#get-apiusersemployeeidemployeeid)
      - [`GET: /api/users/:Id`](#get-apiusersid)
      - [`PATCH: /api/users/:id`](#patch-apiusersid)
      - [`DEL: /api/users/:id`](#del-apiusersid)
    - [Role related actions](#role-related-actions)
      - [`GET: /api/roles`](#get-apiroles)
    - [Authorization related actions](#authorization-related-actions)
      - [`GET: /api/authorizations`](#get-apiauthorizations)
      - [`GET: /api/authorizations/user/:userId`](#get-apiauthorizationsuseruserid)
      - [`POST: /api/authorizations`](#post-apiauthorizations)
      - [`DEL: /api/authorizations/:id`](#del-apiauthorizationsid)
    - [Schemas](#schemas)
      - [User](#user)
      - [Authorization](#authorization)
      - [Role](#role)
  - [Governance](#governance)

## Running the project

> [!NOTE]
> This project requires the .NET8 __Desktop__ runtime. Make sure to download and install the .NET8 runtime from: https://dotnet.microsoft.com/en-us/download/dotnet/thank-you/runtime-desktop-8.0.24-windows-x64-installer

1. Download the application from: https://github.com/Tools4everBV/Basic-Example-Target-API/releases
2. Open the `EXAMPLE.API.MANAGER.exe` file.
3. Click `install` to install API.

![alt text](/assets/appManager.png)

> [!NOTE]
> By default, the project runs on: http://localhost:5006

## Settings

If you wish to make changes to the settings, you can do so by opening the `Settings` window.


![alt text](/assets/appManager.png)

#### Logging

| Setting | Description | Default value |
| --- | --- | --- |
| `LogLevel.Default` | Sets the default logging level for the entire application. Options include `Trace`, `Debug`, `Information`, `Warning`, `Error`, and `Critical`. | `Information` |
| `LogLevel.Microsoft.AspNetCore` | Sets the logging level specifically for ASP.NET Core internals. Usually kept higher to avoid excessive log noise. | `Warning` |

#### Kestrel

| Setting | Description | Default value |
| --- | --- | --- |
 | `Endpoints.Http.Url` | Defines the HTTP endpoint and port on which the API will run locally. | `http://localhost:5006` |
| **AllowedHosts** | *(root setting)* | Specifies which hosts are allowed to access the application. `*` allows all hosts (suitable for local development). | `*` |

#### ApplicationSettings

| Setting | Description | Default value |
| --- | --- | --- |
| **ClientId** | The `ClientId` used to request an OAuth token from the authentication endpoint. This uniquely identifies your application when calling the API. | `339ddde0-7219-4895-ab65-65d5dba91fff` |
| **ClientSecret** | The `ClientSecret` paired with the `ClientId` to securely authenticate and retrieve an OAuth token. Treat this as a secret and do not expose it publicly. | `87a3354033418b90fc00ad9d06cb2cf36baf0276181efae9ce8a1e780cc024a3` |
| **CopyTokenToClipBoard** | When `true`, the retrieved OAuth token will be automatically copied to your clipboard, making it easy to paste into tools like Swagger or Postman for testing. | `false` |

### SQLite database

The project comes with a simple SQLite database. If you need a graphical interface to directly manage the database, go to: https://sqlitebrowser.org/dl/

### Web interface

When the Windows Service is installed properly, you can navigate to: `{url/index.html}`. From there you can either load the:

- User management interface at `{url}/management.html`.
- Swagger interface at: `{url}/swagger/index.html`

## About the API

The following actions are available:

### Authentication

| HTTP Method | Endpoint | Description |
| --- | --- |--- |
| POST | [/api/oauth/token](#post-apiauthtoken) | Retrieve an oAuth token |

#### `POST: /api/auth/token`

We prefer OAuth for authentication because it’s secure, easy to use, and works smoothly with modern apps and APIs.

In order to retrieve a token, in our example API, we make an API call to: `{url}/api/auth/token` containing the following body:

```json
{
    "ClientId": "example-client-id",
    "ClientSecret": "example-client-secret"
}
```

> [!NOTE]
> The **ClientId** and **ClientSecret** are automatically fetched from the `appsettings.json` file.
> If **CopyTokenToClipBoard** is set to `true`, the token will automatically be copied to the clipboard for easy use.

### User related actions

| HTTP Method | Endpoint | Description |
| --- | --- |--- |
| GET | [/api/users](#get-apiuser) | Get all users |
| POST | [/api/users](#post-apiuser) | Adds a user |
| GET | [/api/users/employeeid/:employeeId](#get-apiusersemployeeidemployeeid) | Gets a user by employeeId |
| GET | [/api/users/:Id](#get-apiuserid) | Gets a user by Id |
| PATCH | [/api/users/:id](#patch-apiuserid) | Updates a user |
| DEL | [/api/users/:id](#del-apiuserid) | Deletes a user |

#### `GET: /api/users`

We need to retrieve information about all users to support our import entitlement feature, enable reconciliation, and ultimately ensure proper [governance](#governance).

#### `POST: /api/users`

Adds a new user account to the target system. The response must contain the internal database ID since this is the key we correlate on and will be used for consecutive requests to the target system. Therefore, the `id` field is enlisted in the user schema.

#### `GET: /api/users/employeeid/:employeeId`

Before we add a user account to the target application, we need to validate if that user account exists.

Initially, the internal database ID is not known to us. Therefore, we prefer to validate this using the `EmployeeId` since this is unique and available in HelloID. In our example, validation uses a dedicated API call, though filtering on the `EmployeeId` would work just as well.

> [!NOTE]
> Note that, retrieving all user accounts and do some type of lookup is -in most cases- not very well suited for HelloID and might cause performance issue's.</em>

> [!WARNING]
> We only need to retrieve the user account using the `employeeId` in our initial create event. Subsequent events will use the internal database ID for lookups.

#### `GET: /api/users/:Id`

Before we update a particular user account, we need to validate if that user account still exists.

> [!NOTE]
> Validating if the user account exists is an integral part in all our lifecycle events because the user account might be <em>unintentionally</em> deleted. In which case the lifecycle event will fail. </br></br> **For example:** when we want to enable the user account on the day the contract takes effect.

#### `PATCH: /api/users/:id`

To update a user account we prefer to see an update call in the form of a patch. This means that we only update the values that have been changed.

> [!NOTE]
> In the `Basic-EXAMPLE-Target-API` the patch method is implemented using <a href="https://jsonpatch.com/">JSON Patch</a>. Note that this might not have to be the best solution for your application.

#### `DEL: /api/users/:id`

This action does not require a response. A [204 No Content] is sufficient.

### Role related actions

| HTTP Method | Endpoint | Description |
| --- | --- |--- |
| GET | [/api/roles](#get-apiroles) | Retrieves all roles |

#### `GET: /api/roles`

Before we can assign a role to a user, we first need to retrieve all available roles. Then, we build out our business rules to, ultimately grant authorizations to user based on information coming from an HR source.

### Authorization related actions

| HTTP Method | Endpoint | Description |
| --- | --- |--- |
| GET | [/api/authorizations](#get-apiauthorizations) | Get all authorizations for all users |
| GET | [/api/authorizations/user/:userId](#get-apiauthorizationsuseruserid) | Get all authorizations for a specific user |
| POST | [/api/authorizations](#post-apiuserauthorizationsadd) | Add a new authorization for a specific user |
| DEL | [/api/authorizations/delete/:id](#del-apiuserauthorizationsdeleteroleidroleiduseridid) | Deletes an authorization |

#### `GET: /api/authorizations`

We need to retrieve information about all authorizations (granted to all users) to support our import entitlement feature, enable reconciliation, and ultimately ensure proper [governance](#governance).

#### `GET: /api/authorizations/user/:userId`

An authorization may already be granted or revoked for a user. This endpoint lets us check which authorizations are currently active.

#### `POST: /api/authorizations`

We will use this action when an authorization need to be granted to a user. Since we do not store the result in HelloID, this action does not require a response.

#### `DEL: /api/authorizations/:id`

We will use this action when an authorization needs to be revoked from a user. This action does not require a response. A [204 No Content] is sufficient.

### Schemas

> [!NOTE]
> The schema's listed below contain the bare minimum we need in order to build a solid connector.

#### User

The user schema contains all the parameters we expect to be present in an application. Your application / user schema might have different names for parameters, or far more parameters than enlisted in this schema.

For example: A `PhoneNumber` for two-factor authentication or a more complex multi-layered schema.

| Parameter | Description | Required | Type |
|--- |--- | --- | --- |
| Id | This is the internal / database Id.</br> Typically, this value will be set by the application | - | <em>int</em>
| Active | Defines if the user is active or not. We will update this value when a user is enabled or disabled.</br></br> When we initially create a user, we prefer to create that user in a `disabled state`. On the day the contract takes effect the user account will be enabled. | True | <em>bool</em> |
| [EmployeeId](#get-apiuserbyemployeeidemployeeid) | The EmployeeId or ExternalId of the user. | True | <em>string</em> |
| FirstName | - | True | <em>string</em> |
| LastName | - | True | <em>string</em> |
| Email | - | True | <em>string</em> |

#### Authorization

| Parameter | Description | Required | Type |
|--- |--- | --- | --- |
| Id | This is the internal / database Id.</br> Typically, this value will be set by the application | - | <em>int</em> |
| RoleId | The Id of the role. | True | <em>int</em> |
| UserId | The Id of the user. | True | <em>int</em> |

#### Role

| Parameter | Description | Required | Type |
|--- |--- | --- | --- |
| Id | This is the internal / database Id.</br> Typically, this value will be set by the application | - | <em>int</em> |
| DisplayName | The DisplayName of the role. | True | <em>string</em> |

## Governance

Our governance module in HelloID provides reconciliation for Provisioning.

Reconciliation is aimed to ensure that the state of rights and permissions in target systems is as intended.

Users might change roles, leave the organization, or require adjustments to their access rights over time. Applications will be updated, and errors may occur that also impact access rights. As a result, there can be a misalignment between the entitlements that should have been granted according to HelloID and the actual access rights within the target application.

Reconciliation works by importing account _and_ permission data from the target system and comparing this data against the state of entitlements in HelloID. Any issues — such as unexpected accounts, missing permissions, or mismatching account statuses — are listed and can be resolved.