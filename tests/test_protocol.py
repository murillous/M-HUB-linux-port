"""Testes do protocolo com bytes capturados do V9 Pro 2 real (Windows, 2026-10-16)."""

import unittest

from v9pro2 import protocol as P

h = bytes.fromhex


class BuildParse(unittest.TestCase):
    def test_build_request(self):
        out = P.build(P.REQUEST, P.GET_BATTERY_SLEEP)
        self.assertEqual(len(out), 63)
        self.assertEqual(out[:8], h("aa 01 00 01 00 01 0b 00"))

    def test_build_ota_query(self):
        self.assertEqual(P.build(P.OTA_REQUEST, P.OTA_DONGLE, [P.OTA_QUERY])[:8],
                         h("aa 01 00 02 00 06 01 80"))

    def test_parse_checks_checksum(self):
        good = h("aa 01 01 03 00 01 0b 01 54 5d") + bytes(53)
        self.assertEqual(P.parse(good), ((0, 1), 11, h("01 54")))
        bad = bytearray(good)
        bad[9] ^= 1
        self.assertIsNone(P.parse(bytes(bad)))


class Decode(unittest.TestCase):
    def test_battery(self):
        self.assertEqual(P.decode_battery_sleep(h("01 54")),
                         {"asleep": False, "sleep_state": 1, "charging": False, "percent": 84})

    def test_auto_shutdown(self):
        self.assertEqual(P.decode_auto_shutdown(h("00 1e")), {"minutes": 30, "never": False})

    def test_eq_mode_desc_utf8(self):
        p = h("02 e5 ae 98 e6 96 b9 e9 a2 84 e8 ae be 2d e9 9f b3 e4 b9 90 00")
        self.assertEqual(P.decode_eq_mode_desc(p)["name"], "官方预设-音乐")

    def test_eq_all_points_two_packets(self):
        p1 = h("00 ff 00 00 0a 59 00 2d 00 14 08 00 01 00 64 00 23 07 00 01 00 fa ff dd 08 00 01"
               " 01 90 00 37 0c 00 01 03 e8 00 0f 0b 00 01")
        p2 = h("00 ff 00 00 0a 5a 07 d0 00 1e 07 00 01 0f a0 00 14 07 00 01 17 70 00 19 08 00 01"
               " 1f 40 00 0a 0a 00 01 2e e0 ff f6 09 00 01")
        self.assertFalse(P.eq_points_complete([p1]))
        self.assertTrue(P.eq_points_complete([p2, p1]))
        eq = P.decode_eq_all_points([p2, p1])
        self.assertEqual([pt["fc"] for pt in eq["points"]],
                         [45, 100, 250, 400, 1000, 2000, 4000, 6000, 8000, 12000])
        self.assertEqual(eq["points"][2]["gain_db"], -3.5)
        self.assertEqual(eq["points"][9], {"fc": 12000, "gain_db": -1.0, "q": 0.9,
                                           "type": 0, "enable": True})

    def test_version(self):
        self.assertEqual(P.decode_version(h("80 00 00 00 33")), {"version": "0033"})

    def test_descriptor_has_report_55(self):
        desc = h("06 07 ff 0a 22 02 a1 01 85 55 09 02 15 00 25 ff 75 08 95 3f 81 02"
                 " 85 55 09 01 15 00 25 ff 75 08 95 3f 91 02 c0")
        self.assertTrue(P.has_output_report(desc))
        self.assertFalse(P.has_output_report(h("05 0c 09 01 a1 01 85 01 09 00 91 02 c0")))


if __name__ == "__main__":
    unittest.main()


class Encode(unittest.TestCase):
    def test_set_prompt_volume(self):
        self.assertEqual(P.build(P.SET, P.SET_PROMPT_VOLUME, P.encode_set_prompt_volume(8))[:9],
                         h("aa 01 00 02 00 02 21 08 00"))
        for bad in (0, 17):
            self.assertRaises(ValueError, P.encode_set_prompt_volume, bad)

    def test_set_eq_mode(self):
        self.assertEqual(P.encode_set_eq_mode(2), [2])
        self.assertRaises(ValueError, P.encode_set_eq_mode, 3)

    def test_set_eq_gains(self):
        gains = [2, 3.5, -3.5, 5.5, 1.5, 3, 2, 2.5, 1, -1]
        p = P.encode_set_eq_gains(2, gains)
        self.assertEqual(p[:6], [2, 10, 0x00, 0x14, 0x00, 0x23])
        self.assertEqual(p[6:8], [0xFF, 0xDD])  # -3.5 dB
        self.assertEqual(len(P.build(P.SET, P.SET_EQ_GAINS, p)), 63)
        self.assertRaises(ValueError, P.encode_set_eq_gains, 2, gains[:9])
        self.assertRaises(ValueError, P.encode_set_eq_gains, 2, [12.5] + gains[1:])

    def test_set_auto_shutdown(self):
        self.assertEqual(P.encode_set_auto_shutdown(30), [0x00, 0x1E])
        self.assertEqual(P.encode_set_auto_shutdown(0), [0, 0])
        self.assertRaises(ValueError, P.encode_set_auto_shutdown, 20)
