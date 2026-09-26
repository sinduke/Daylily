#!/usr/bin/env python3
import copy
import importlib.util
import json
import pathlib
import unittest
import sys
sys.dont_write_bytecode = True

HERE = pathlib.Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('compatibility', HERE.parents[2] / 'scripts/openapi-compatibility-check.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
BASE = json.loads((HERE / 'old.json').read_text())


class CompatibilityTests(unittest.TestCase):
    @staticmethod
    def schema_document(schema, direction):
        media = {'content': {'application/json': {'schema': schema}}}
        operation = {'responses': {'200': {'description': 'OK'}}}
        if direction == 'request':
            operation['requestBody'] = media
        else:
            operation['responses']['200'].update(media)
        return {'openapi': '3.1.0', 'paths': {'/value': {'post': operation}}}

    def compare_schema(self, old, new, direction):
        return module.compare(self.schema_document(old, direction), self.schema_document(new, direction))

    def test_nullable_required_matrix(self):
        # Independent finite wire-value model: absence, explicit null and a string.
        for old_required in (False, True):
            for new_required in (False, True):
                for old_nullable in (False, True):
                    for new_nullable in (False, True):
                        def contract(required, nullable):
                            return {'type': 'object', 'properties': {'note': {'type': ['string', 'null'] if nullable else 'string'}},
                                    'required': ['note'] if required else []}
                        def values(required, nullable):
                            return {'value'} | ({'absent'} if not required else set()) | ({'null'} if nullable else set())
                        for direction in ('request', 'response'):
                            with self.subTest(old_required=old_required, new_required=new_required,
                                              old_nullable=old_nullable, new_nullable=new_nullable, direction=direction):
                                a, b = values(old_required, old_nullable), values(new_required, new_nullable)
                                result = self.compare_schema(contract(old_required, old_nullable), contract(new_required, new_nullable), direction)
                                self.assertTrue(result['supported'], result)
                                self.assertEqual(result['compatible'], a <= b if direction == 'request' else b <= a, result)

    def test_nullable_enum_intersection(self):
        # A nullable type alone does not permit null when enum excludes it.
        schemas = [
            ({'type': 'string', 'enum': ['a']}, {'a'}),
            ({'type': ['string', 'null'], 'enum': ['a']}, {'a'}),
            ({'type': ['null', 'string'], 'enum': ['a', None]}, {'a', None}),
            ({'type': ['string', 'null'], 'enum': [None]}, {None}),
            ({'type': 'null'}, {None}),
            ({'type': 'string', 'enum': ['a', None]}, {'a'}),
        ]
        for old, a in schemas:
            for new, b in schemas:
                for direction in ('request', 'response'):
                    with self.subTest(old=old, new=new, direction=direction):
                        result = self.compare_schema(old, new, direction)
                        self.assertTrue(result['supported'], result)
                        self.assertEqual(result['compatible'], a <= b if direction == 'request' else b <= a, result)

    def test_nullable_arrays_objects_and_local_references(self):
        for schema in ({'type': ['array', 'null'], 'items': {'type': ['string', 'null']}},
                       {'type': ['object', 'null'], 'properties': {'value': {'type': 'string'}}}):
            self.assertTrue(self.compare_schema(schema, copy.deepcopy(schema), 'request')['compatible'])
        old = self.schema_document({'$ref': '#/components/schemas/Note'}, 'request')
        old['components'] = {'schemas': {'Note': {'type': ['string', 'null']}}}
        new = copy.deepcopy(old)
        new['components']['schemas']['Note']['type'] = 'string'
        result = module.compare(old, new)
        self.assertIn('request-null-removed', {finding['code'] for finding in result['findings']})

    def test_general_unions_and_nullable_ref_siblings_still_unsupported(self):
        for schema in ({'type': ['string', 'integer']}, {'type': ['string', 'null', 'integer']},
                       {'type': ['null', 'null']}, {'type': ['string']}, {'type': []},
                       {'type': 'string', 'nullable': True}):
            result = self.compare_schema({'type': 'string'}, schema, 'request')
            self.assertFalse(result['supported'], result)
            self.assertIsNone(result['compatible'], result)
        old = self.schema_document({'$ref': '#/components/schemas/Note'}, 'request')
        old['components'] = {'schemas': {'Note': {'type': 'string'}}}
        new = copy.deepcopy(old)
        new['paths']['/value']['post']['requestBody']['content']['application/json']['schema']['type'] = ['string', 'null']
        self.assertFalse(module.compare(old, new)['supported'])

    def test_nullable_fixture_outcomes(self):
        old = json.loads((HERE / 'nullable-old.json').read_text())
        compatible = module.compare(old, json.loads((HERE / 'nullable-compatible.json').read_text()))
        self.assertTrue(compatible['supported'], compatible)
        self.assertTrue(compatible['compatible'], compatible)
        breaking = module.compare(old, json.loads((HERE / 'nullable-breaking.json').read_text()))
        self.assertTrue(breaking['supported'], breaking)
        self.assertEqual({f['code'] for f in breaking['findings']}, {'request-null-removed', 'response-null-added'})

    def test_empty_or_nonfinite_enum_intersection_is_unsupported(self):
        for schema in ({'type': 'string', 'enum': [None]}, {'type': 'null', 'enum': ['a']},
                       {'type': 'number', 'enum': [float('nan')]}, {'type': 'integer', 'enum': [float('inf')]}):
            self.assertFalse(self.compare_schema({'type': 'string'}, schema, 'request')['supported'])

    def check_change(self, mutate, code=None, compatible=False, supported=True):
        new = copy.deepcopy(BASE)
        mutate(new)
        result = module.compare(BASE, new)
        self.assertEqual(result['supported'], supported, result)
        if supported:
            self.assertEqual(result['compatible'], compatible, result)
        if code:
            self.assertIn(code, {f['code'] for f in result['findings']}, result)
        return result

    def test_identity(self):
        self.assertTrue(module.compare(BASE, copy.deepcopy(BASE))['compatible'])

    def test_compatible_fixture(self):
        self.assertTrue(module.compare(BASE, json.loads((HERE / 'compatible.json').read_text()))['compatible'])

    def test_new_required_request_field(self):
        result = module.compare(BASE, json.loads((HERE / 'breaking-required.json').read_text()))
        self.assertIn('request-required-added', {f['code'] for f in result['findings']})

    def test_type_change(self):
        self.check_change(lambda d: d['components']['schemas']['EchoInput']['properties']['message'].update(type='integer'), 'type-changed')

    def test_removed_endpoint(self):
        self.check_change(lambda d: d['paths'].pop('/echo'), 'operation-removed')

    def test_response_enum_narrowing_is_safe(self):
        self.check_change(lambda d: d['components']['schemas']['Greeting']['properties']['labels']['items'].update(enum=['daylily']), compatible=True)

    def test_response_enum_expansion_breaks_old_decoder(self):
        self.check_change(lambda d: d['components']['schemas']['Greeting']['properties']['labels']['items']['enum'].append('unknown'), 'response-enum-expanded')

    def test_request_enum_narrowing_breaks_old_requests(self):
        self.check_change(lambda d: d['components']['schemas']['EchoInput']['properties']['message'].update(enum=['only']), 'request-enum-narrowed')

    def test_request_enum_expansion_is_safe(self):
        old=copy.deepcopy(BASE);old['components']['schemas']['EchoInput']['properties']['message']['enum']=['a']
        new=copy.deepcopy(old);new['components']['schemas']['EchoInput']['properties']['message']['enum'].append('b')
        self.assertTrue(module.compare(old,new)['compatible'])

    def test_response_required_removed(self):
        self.check_change(lambda d: d['components']['schemas']['Greeting']['required'].remove('message'), 'response-required-removed')

    def test_request_required_removed_is_safe(self):
        self.check_change(lambda d: d['components']['schemas']['EchoInput']['required'].clear(), compatible=True)

    def test_required_query_added(self):
        self.check_change(lambda d: d['paths']['/echo']['post']['parameters'].append(dict(name='tenant', **{'in':'query'}, required=True, schema={'type':'string'})), 'request-parameter-required-added')

    def test_optional_query_added(self):
        self.check_change(lambda d: d['paths']['/echo']['post']['parameters'].append(dict(name='trace', **{'in':'query'}, schema={'type':'string'})), compatible=True)

    def test_recursive_local_schema_terminates(self):
        old=copy.deepcopy(BASE);g=old['components']['schemas']['Greeting'];g['properties']['next']={'$ref':'#/components/schemas/Greeting'}
        self.assertTrue(module.compare(old,copy.deepcopy(old))['compatible'])

    def test_composition_is_unknown(self):
        self.check_change(lambda d: d['components']['schemas']['EchoInput'].update(oneOf=[]), supported=False)

    def test_external_ref_is_unknown(self):
        self.check_change(lambda d: d['paths']['/echo']['post']['requestBody']['content']['application/json'].update(schema={'$ref':'https://example.invalid/schema'}), supported=False)

    def test_missing_ref_is_unknown(self):
        self.check_change(lambda d: d['components']['schemas'].pop('EchoInput'), supported=False)

    def test_malformed_paths_is_unknown(self):
        self.assertFalse(module.compare(BASE, {'openapi':'3.1.0','paths':[]})['supported'])

    def test_added_constraints_are_unknown(self):
        self.check_change(lambda d: d['components']['schemas']['EchoInput']['properties']['message'].update(minLength=10), supported=False)

    def test_new_status_is_breaking(self):
        self.check_change(lambda d: d['paths']['/echo']['post']['responses'].update({'202':{'description':'Accepted'}}), 'response-status-added')

    def compare_responses(self, old, new):
        def document(responses):
            return {'openapi': '3.1.0', 'paths': {'/value': {'get': {'responses': {
                status: {'description': 'Value', 'content': {'application/json': {'schema': {'type': kind}}}}
                for status, kind in responses.items()
            }}}}}
        return module.compare(document(old), document(new))

    def test_removed_explicit_status_uses_new_default_against_old_explicit_decoder(self):
        result = self.compare_responses({'200': 'integer', 'default': 'string'}, {'default': 'string'})
        self.assertTrue(result['supported'], result)
        self.assertFalse(result['compatible'], result)
        self.assertIn({'code': 'type-changed', 'location': 'GET /value/responses/200/application/json',
                       'direction': 'response', 'reason': 'Schema type/format changed; generated value representations may differ'}, result['findings'])

    def test_removed_explicit_status_with_compatible_default_is_safe(self):
        result = self.compare_responses({'200': 'string', 'default': 'string'}, {'default': 'string'})
        self.assertTrue(result['supported'], result)
        self.assertTrue(result['compatible'], result)

    def test_removed_explicit_status_without_fallback_narrows_response_space(self):
        result = self.compare_responses({'200': 'integer', '201': 'string'}, {'201': 'string'})
        self.assertTrue(result['compatible'], result)

    def test_added_explicit_status_uses_old_default_decoder(self):
        result = self.compare_responses({'default': 'integer'}, {'200': 'string', 'default': 'integer'})
        self.assertTrue(result['supported'], result)
        self.assertFalse(result['compatible'], result)
        self.assertIn('type-changed', {f['code'] for f in result['findings']})

    def test_existing_explicit_decoder_takes_precedence_over_default(self):
        responses = {'200': 'integer', 'default': 'string'}
        result = self.compare_responses(responses, responses)
        self.assertTrue(result['compatible'], result)

    def test_response_status_ranges_are_unsupported_in_either_document(self):
        for status in ('1XX', '2XX', '3XX', '4XX', '5XX'):
            for old, new in (({status: 'integer'}, {status: 'integer', '200': 'integer'}),
                             ({'200': 'integer'}, {status: 'integer'}),
                             ({status: 'integer'}, {status: 'integer'})):
                with self.subTest(status=status, old=old, new=new):
                    result = self.compare_responses(old, new)
                    self.assertFalse(result['supported'], result)
                    self.assertIsNone(result['compatible'], result)
                    self.assertIn('status ranges are unsupported', result['error'])

    def test_malformed_response_status_is_unsupported(self):
        for status in ('099', '600', '20', '2000', '2xx', '２００', 200):
            with self.subTest(status=status):
                result = self.compare_responses({'200': 'integer'}, {status: 'integer'})
                self.assertFalse(result['supported'], result)
                self.assertIsNone(result['compatible'], result)

    def test_request_media_removed(self):
        self.check_change(lambda d: d['paths']['/echo']['post']['requestBody']['content'].clear(), 'request-media-removed')

    def test_new_response_media_is_breaking(self):
        self.check_change(lambda d: d['paths']['/echo']['post']['responses']['200']['content'].update({'text/plain':{'schema':{'type':'string'}}}), 'response-media-added')


if __name__ == '__main__':
    unittest.main()
