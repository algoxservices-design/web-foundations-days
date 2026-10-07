# Library Books REST API

This API manages books in a library system. The main resource is `books`.

## API Base URL

`https://api.example.com`

## Endpoints

### 1. List all books

- **Method:** `GET`
- **Path:** `/books`
- **Description:** Returns a list of all books in the library.
- **Success status:** `200 OK`

Example request:

```http
GET /books
