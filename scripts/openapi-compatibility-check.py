#!/usr/bin/env python3
"""Conservative wire compatibility check: old generated clients -> new server.

Exit 0: supported and compatible; 1: breaking change; 2: unsupported/invalid input.
This is deliberately a documented subset, not a full OpenAPI/JSON Schema validator.
"""
import argparse
import json
import math
import pathlib
import sys

METHODS = {'get', 'put', 'post', 'delete', 'options', 'head', 'patch', 'trace'}
SCHEMA_KEYS = {'type', 'format', 'properties', 'required', 'items', 'enum', '$ref',
               'additionalProperties', 'title', 'description', 'default', 'example',
               'examples', 'deprecated'}
TYPES = {'string', 'integer', 'number', 'boolean', 'object', 'array', 'null'}


def schema_types(schema):
    value = schema.get('type')
    if isinstance(value, str) and value in TYPES:
        return {value}
    if (isinstance(value, list) and len(value) == 2
            and all(isinstance(item, str) and item in TYPES for item in value)
            and len(set(value)) == 2 and 'null' in value):
        return set(value)
    raise Unsupported('A single supported type or exactly one concrete type plus null is required; arbitrary unions are unsupported')


def scalar_matches(value, types):
    if value is None:
        return 'null' in types
    if isinstance(value, bool):
        return 'boolean' in types
    if isinstance(value, str):
        return 'string' in types
    if isinstance(value, (int, float)):
        if isinstance(value, float) and not math.isfinite(value):
            raise Unsupported('Enum numbers must be finite JSON values')
        return 'number' in types or ('integer' in types and int(value) == value)
    return False


def allowed_enum(schema):
    if 'enum' not in schema:
        return None
    types = schema_types(schema)
    return [value for value in schema['enum'] if scalar_matches(value, types)]


def admits_null(schema):
    values = allowed_enum(schema)
    return 'null' in schema_types(schema) and (values is None or None in values)


def concrete_type(schema):
    values = allowed_enum(schema)
    if values is not None and all(value is None for value in values):
        return None
    return next(iter(schema_types(schema) - {'null'}), None)


class Unsupported(ValueError):
    pass


class Checker:
    def __init__(self, old, new):
        self.old, self.new = old, new
        self.findings = []
        self.compared = set()

    def issue(self, code, location, direction, reason):
        value = dict(code=code, location=location, direction=direction, reason=reason)
        if value not in self.findings:
            self.findings.append(value)

    def resolve(self, schema, document):
        seen = set()
        while '$ref' in schema:
            ref = schema['$ref']
            if not isinstance(ref, str) or not ref.startswith('#/components/schemas/'):
                raise Unsupported('Only local #/components/schemas references are supported')
            if ref in seen:
                raise Unsupported('A reference cycle without a concrete schema is unsupported')
            seen.add(ref)
            if set(schema) - {'$ref', 'description', 'title'}:
                raise Unsupported('$ref siblings with validation semantics are unsupported')
            current = document
            try:
                for part in ref[2:].split('/'):
                    current = current[part.replace('~1', '/').replace('~0', '~')]
            except (KeyError, TypeError):
                raise Unsupported('Unresolved schema reference: ' + ref)
            if not isinstance(current, dict):
                raise Unsupported('Schema reference does not resolve to an object: ' + ref)
            schema = current
        return schema

    def validate_schema(self, schema, document, seen):
        if not isinstance(schema, dict):
            raise Unsupported('Boolean schemas and non-object schemas are unsupported')
        schema = self.resolve(schema, document)
        if id(schema) in seen:
            return
        seen.add(id(schema))
        unknown = {k for k in schema if k not in SCHEMA_KEYS and not k.startswith('x-')}
        if unknown:
            raise Unsupported('Unsupported schema keywords: ' + ', '.join(sorted(unknown)))
        types = schema_types(schema)
        kind = next(iter(types - {'null'}), None)
        if 'enum' in schema and (not isinstance(schema['enum'], list) or not schema['enum']):
            raise Unsupported('enum must be a nonempty array')
        if 'enum' in schema and any(isinstance(v, (dict, list)) for v in schema['enum']):
            raise Unsupported('Only scalar enum values (including null) are supported')
        if 'enum' in schema and not allowed_enum(schema):
            raise Unsupported('An enum with no values matching its type is outside this subset')
        if kind != 'object' and any(k in schema for k in ('properties', 'required', 'additionalProperties')):
            raise Unsupported('Object constraints on a non-object schema are unsupported')
        if kind != 'array' and 'items' in schema:
            raise Unsupported('Items constraints on a non-array schema are unsupported')
        if 'additionalProperties' in schema and not isinstance(schema['additionalProperties'], bool):
            raise Unsupported('Only boolean additionalProperties is supported')
        if kind == 'array':
            if 'items' not in schema:
                raise Unsupported('Array items schema is required')
            self.validate_schema(schema['items'], document, seen)
        if kind == 'object':
            properties = schema.get('properties', {})
            required = schema.get('required', [])
            if not isinstance(properties, dict) or not isinstance(required, list) or any(not isinstance(x, str) for x in required):
                raise Unsupported('Invalid object properties/required')
            if set(required) - properties.keys():
                raise Unsupported('Required properties must be explicitly declared')
            for value in properties.values():
                self.validate_schema(value, document, seen)

    def parameters(self, item, operation):
        result = {}
        for parameter in item.get('parameters', []) + operation.get('parameters', []):
            if not isinstance(parameter, dict) or '$ref' in parameter or 'schema' not in parameter:
                raise Unsupported('Parameters must be inline with a schema')
            if parameter.get('in') not in {'path', 'query', 'header', 'cookie'} or not isinstance(parameter.get('name'), str):
                raise Unsupported('Invalid parameter location or name')
            if any(k in parameter for k in ('style', 'explode', 'content', 'allowReserved', 'allowEmptyValue')):
                raise Unsupported('Custom parameter serialization is unsupported')
            name = parameter['name'].lower() if parameter['in'] == 'header' else parameter['name']
            result[(parameter['in'], name)] = parameter
        return result

    def validate(self, document):
        if not isinstance(document, dict) or not str(document.get('openapi', '')).startswith('3.1.'):
            raise Unsupported('Only OpenAPI 3.1 JSON documents are supported')
        if document.get('jsonSchemaDialect'):
            raise Unsupported('An explicit JSON Schema dialect is outside this subset')
        if document.get('security') or document.get('webhooks'):
            raise Unsupported('Security requirements and webhooks are outside this subset')
        if not isinstance(document.get('paths'), dict):
            raise Unsupported('paths must be an object')
        for path, item in document['paths'].items():
            if not isinstance(item, dict) or '$ref' in item:
                raise Unsupported('Path items must be inline objects')
            for method, operation in item.items():
                if method not in METHODS:
                    continue
                if not isinstance(operation, dict):
                    raise Unsupported('Operation must be an object')
                if operation.get('security') or operation.get('callbacks'):
                    raise Unsupported('Security requirements and callbacks are outside this subset')
                for parameter in self.parameters(item, operation).values():
                    self.validate_schema(parameter['schema'], document, set())
                body = operation.get('requestBody')
                responses = operation.get('responses')
                if not isinstance(responses, dict) or not responses:
                    raise Unsupported('Operation responses must be nonempty')
                for status in responses:
                    if status != 'default' and not (
                        isinstance(status, str) and len(status) == 3
                        and status[0] in '12345' and all(c in '0123456789' for c in status[1:])
                    ):
                        raise Unsupported('Response keys must be exact HTTP status codes (100–599) or default; status ranges are unsupported')
                values = ([body] if body is not None else []) + list(responses.values())
                for value in values:
                    if not isinstance(value, dict) or '$ref' in value or value.get('headers') or value.get('links'):
                        raise Unsupported('Only inline body/response definitions without headers/links are supported')
                    for media in value.get('content', {}).values():
                        if not isinstance(media, dict) or 'schema' not in media or media.get('encoding'):
                            raise Unsupported('Media types require a schema; custom encoding is unsupported')
                        self.validate_schema(media['schema'], document, set())

    def schema(self, old, new, location, direction):
        old, new = self.resolve(old, self.old), self.resolve(new, self.new)
        key = (id(old), id(new), direction)
        if key in self.compared:
            return
        self.compared.add(key)
        old_null, new_null = admits_null(old), admits_null(new)
        if direction == 'request' and old_null and not new_null:
            self.issue('request-null-removed', location, direction, 'New server rejects JSON null accepted by the old request contract')
        if direction == 'response' and new_null and not old_null:
            self.issue('response-null-added', location, direction, 'New response permits JSON null rejected by the old client contract')
        old_kind, new_kind = concrete_type(old), concrete_type(new)
        if old_kind is None or new_kind is None:
            if direction == 'request' and old_kind is not None:
                self.issue('request-non-null-removed', location, direction, 'New server rejects non-null values accepted by the old request contract')
            if direction == 'response' and new_kind is not None:
                self.issue('response-non-null-added', location, direction, 'New response permits non-null values rejected by the old null-only contract')
            return
        if old_kind != new_kind or old.get('format') != new.get('format'):
            self.issue('type-changed', location, direction, 'Schema type/format changed; generated value representations may differ')
            return
        old_enum, new_enum = allowed_enum(old), allowed_enum(new)
        a = {json.dumps(v, sort_keys=True) for v in old_enum if v is not None} if old_enum is not None else None
        b = {json.dumps(v, sort_keys=True) for v in new_enum if v is not None} if new_enum is not None else None
        if direction == 'request' and b is not None and (a is None or not a <= b):
            self.issue('request-enum-narrowed', location, direction, 'New server rejects enum values accepted by the old request contract')
        if direction == 'response' and a is not None and (b is None or not b <= a):
            self.issue('response-enum-expanded', location, direction, 'New response permits enum values unknown to the old client')
        if old_kind == 'array':
            self.schema(old['items'], new['items'], location + '/items', direction)
        if old_kind != 'object':
            return
        old_props, new_props = old.get('properties', {}), new.get('properties', {})
        old_required, new_required = set(old.get('required', [])), set(new.get('required', []))
        if direction == 'request':
            for name in sorted(new_required - old_required):
                self.issue('request-required-added', location + '/properties/' + name, direction, 'Old clients may omit a newly required request property')
            if old.get('additionalProperties', True) and not new.get('additionalProperties', True):
                self.issue('request-object-closed', location, direction, 'New server disallows previously accepted additional properties')
            if not new.get('additionalProperties', True):
                for name in sorted(old_props.keys() - new_props.keys()):
                    self.issue('request-property-removed', location + '/properties/' + name, direction, 'New closed request object rejects this old property')
        else:
            for name in sorted(old_required - new_required):
                self.issue('response-required-removed', location + '/properties/' + name, direction, 'New response no longer guarantees a property required by the old client')
            if not old.get('additionalProperties', True):
                if new.get('additionalProperties', True):
                    self.issue('response-object-opened', location, direction, 'New server may emit unknown properties rejected by the old closed schema')
                for name in sorted(new_props.keys() - old_props.keys()):
                    self.issue('response-property-added-to-closed-object', location + '/properties/' + name, direction, 'Old closed response schema rejects this new property')
        for name in sorted(old_props.keys() & new_props.keys()):
            self.schema(old_props[name], new_props[name], location + '/properties/' + name, direction)

    def content(self, old, new, location, direction):
        old, new = old.get('content', {}), new.get('content', {})
        # Requests must retain old accepted media; responses must not introduce media old clients cannot decode.
        lost = old.keys() - new.keys() if direction == 'request' else new.keys() - old.keys()
        for media in sorted(lost):
            self.issue('request-media-removed' if direction == 'request' else 'response-media-added', location + '/' + media, direction, 'Media type changes can invalidate old client requests or decoding')
        if direction == 'response' and old and not new:
            self.issue('response-body-removed', location, direction, 'Old client expects a response body')
        for media in sorted(old.keys() & new.keys()):
            self.schema(old[media]['schema'], new[media]['schema'], location + '/' + media, direction)

    def run(self):
        self.validate(self.old)
        self.validate(self.new)
        for path, old_item in self.old['paths'].items():
            new_item = self.new['paths'].get(path, {})
            for method, old in old_item.items():
                if method not in METHODS:
                    continue
                location = method.upper() + ' ' + path
                if method not in new_item:
                    self.issue('operation-removed', location, 'request', 'Old client endpoint is no longer available')
                    continue
                new = new_item[method]
                a, b = self.parameters(old_item, old), self.parameters(new_item, new)
                for key, value in b.items():
                    if value.get('required', False) and (key not in a or not a[key].get('required', False)):
                        self.issue('request-parameter-required-added', location + '/' + ':'.join(key), 'request', 'Old clients may omit this newly required parameter')
                for key in sorted(a.keys() & b.keys()):
                    self.schema(a[key]['schema'], b[key]['schema'], location + '/' + ':'.join(key), 'request')
                old_body, new_body = old.get('requestBody', {}), new.get('requestBody', {})
                if new_body.get('required', False) and not old_body.get('required', False):
                    self.issue('request-body-required-added', location, 'request', 'Old clients may omit the newly required body')
                if old_body and not new_body:
                    self.issue('request-body-removed', location, 'request', 'New contract no longer declares acceptance of the old request body')
                self.content(old_body, new_body, location + '/requestBody', 'request')
                a, b = old['responses'], new['responses']
                for status in sorted(b.keys() - a.keys()):
                    if 'default' not in a:
                        self.issue('response-status-added', location + '/responses/' + status, 'response', 'Old client has no declared decoder for this response status')
                    else:
                        self.content(a['default'], b[status], location + '/responses/' + status, 'response')
                for status in sorted(a.keys() & b.keys()):
                    self.content(a[status], b[status], location + '/responses/' + status, 'response')
                # A new default can still emit a removed explicit status. The old
                # client selects its explicit decoder before its own default.
                if 'default' in b:
                    for status in sorted(a.keys() - b.keys() - {'default'}):
                        self.content(a[status], b['default'], location + '/responses/' + status, 'response')
        return self.findings


def compare(old, new):
    try:
        findings = Checker(old, new).run()
        return dict(compatible=not findings, supported=True, direction='old-client-to-new-server', findings=findings)
    except (Unsupported, TypeError, KeyError, AttributeError) as error:
        return dict(compatible=None, supported=False, direction='old-client-to-new-server', findings=[], error=str(error))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('old', type=pathlib.Path)
    parser.add_argument('new', type=pathlib.Path)
    parser.add_argument('--output', type=pathlib.Path)
    args = parser.parse_args()
    try:
        result = compare(json.loads(args.old.read_text()), json.loads(args.new.read_text()))
    except (OSError, ValueError) as error:
        result = dict(compatible=None, supported=False, error=str(error))
    text = json.dumps(result, indent=2, sort_keys=True) + '\n'
    if args.output:
        args.output.write_text(text)
    print(text, end='')
    return 2 if not result['supported'] else (0 if result['compatible'] else 1)


if __name__ == '__main__':
    sys.exit(main())
