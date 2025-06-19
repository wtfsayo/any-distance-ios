// Licensed under the Any Distance Source-Available License
//
//  Weather+AD.swift
//  ADAC
//
//  Created by Daniel Kuntz on 6/26/23.
//

import WeatherKit
import SwiftUIX

extension CurrentWeather {
    var temperatureIconName: String {
        switch temperature.value {
        case (-1 * Double.greatestFiniteMagnitude)..<0.0:
            return "thermometer.snowflake"
        case 0.0..<8.0:
            return "thermometer.low"
        case 8.0..<25.0:
            return "thermometer.medium"
        case 25.0..<(Double.greatestFiniteMagnitude):
            return "thermometer.high"
        default:
            return "thermometer.medium"
        }
    }

    var temperatureColor: Color {
        switch temperature.value {
        case (-1 * Double.greatestFiniteMagnitude)..<0.0:
            return Color(hexadecimal: "2E6DFA")
        case 0.0..<8.0:
            return Color(hexadecimal: "00EFFF")
        case 8.0..<25.0:
            return Color(hexadecimal: "C8FF00")
        case 25.0..<(Double.greatestFiniteMagnitude):
            return .adOrangeLighter
        default:
            return .adOrangeLighter
        }
    }
}

extension WeatherCondition {
    var iconName: String {
        switch self {
        case .blizzard, .blowingSnow:
            return "wind.snow"
        case .blowingDust, .breezy:
            return "wind"
        case .clear:
            return "sun.max"
        case .cloudy:
            return "smoke"
        case .drizzle:
            return "cloud.drizzle"
        case .flurries, .heavySnow, .snow:
            return "cloud.snow"
        case .foggy:
            return "cloud.fog"
        case .freezingDrizzle, .freezingRain, .sleet, .wintryMix:
            return "cloud.sleet"
        case .frigid:
            return "snowflake"
        case .hail:
            return "cloud.hail"
        case .haze:
            return "cloud.fog"
        case .heavyRain:
            return "cloud.heavyrain"
        case .hot:
            return "sun.max.trainglebadge"
        case .hurricane:
            return "hurricane"
        case .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms, .thunderstorms:
            return "cloud.bolt.rain"
        case .mostlyClear, .partlyCloudy, .sunFlurries:
            return "cloud.sun"
        case .mostlyCloudy:
            return "cloud"
        case .rain:
            return "cloud.rain"
        case .smoky, .windy:
            return "wind"
        case .sunShowers:
            return "cloud.sun.rain"
        case .tropicalStorm:
            return "tropicalstorm"
        @unknown default:
            return "sun.max"
        }
    }

    var iconColor: Color {
        switch self {
        case .blizzard, .blowingSnow, .flurries, .freezingDrizzle, .freezingRain, .heavyRain, .heavySnow, .sleet, .snow, .windy, .wintryMix:
            return Color(hexadecimal: "00EFFF")
        case .blowingDust:
            return .adOrangeLighter
        case .breezy, .cloudy, .drizzle, .foggy, .haze, .mostlyCloudy, .partlyCloudy, .rain, .smoky:
            return Color(hexadecimal: "C8E6FF")
        case .clear, .mostlyClear, .sunFlurries, .sunShowers:
            return .adYellow
        case .frigid, .hail:
            return Color(hexadecimal: "2E6DFA")
        case .hot:
            return .adYellow
        case .hurricane, .tropicalStorm:
            return Color(hexadecimal: "EA54FF")
        case .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms, .thunderstorms:
            return .adYellow
        @unknown default:
            return .adYellow
        }
    }

    var secondaryIconColor: Color? {
        switch self {
        case .mostlyClear, .partlyCloudy, .sunFlurries, .sunShowers:
            return .adYellow
        case .rain, .flurries, .heavySnow, .snow, .foggy, .freezingDrizzle, .freezingRain, .sleet, .wintryMix, .hail, .haze, .heavyRain:
            return .white
        case .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms, .thunderstorms:
            return Color(hexadecimal: "C8E6FF")
        case .hot:
            return .adOrangeLighter
        default:
            return nil
        }
    }

    var message: String {
        switch self {
        case .blizzard:
            return "With a blizzard raging, it's a great day for a home workout. How about some strength training? ❄️"
        case .blowingDust:
            return "A bit dusty outside, isn't it? How about some indoor yoga to keep active? 🧘‍♀️"
        case .blowingSnow:
            return "The snow's blowing outside, but we're still going strong. Time for some indoor cardio! ❄️"
        case .breezy:
            return "A gentle breeze is a runner's best friend. Let's catch the wind and push those limits! 🌬️"
        case .clear:
            return "The sky's clear and the air is fresh. Let's lace up those shoes and hit the pavement! 🏃‍♀️"
        case .cloudy:
            return "The sun's taking a break today, but we don't have to. Perfect weather for a brisk walk! ☁️"
        case .drizzle:
            return "A light drizzle can make a walk feel even more refreshing. Grab your raincoat, and let's go! 🌧️"
        case .flurries:
            return "A sprinkle of snowflakes adds a bit of magic to a winter walk. Bundle up and let's get moving! ❄️"
        case .foggy:
            return "Embrace the mysterious atmosphere and enjoy a relaxing jog in the fog. Remember to stay safe! 🌫️"
        case .freezingDrizzle:
            return "The weather might be icy, but we're just warming up. Let's get moving with an indoor workout! 🌧️"
        case .freezingRain:
            return "Freezing rain means it's a great day for a warm, indoor workout. Time to break a sweat! ❄️"
        case .frigid:
            return "The chill outside is intense, but so are we. Warm up with some indoor cardio! ❄️"
        case .hail:
            return "Hail's falling outside, but that won't stop us. How about an indoor HIIT session? ❄️"
        case .haze:
            return "The haze can't stop us! Let's do some indoor cardio to get that heart rate up. 💪"
        case .heavyRain:
            return "With the rain pouring down, it's a great opportunity for an indoor strength-training session. 🌧️"
        case .heavySnow:
            return "As the snow piles up, so can our reps. Let's tackle an indoor strength workout! ❄️"
        case .hot:
            return "It's hot out there! Stay cool and hydrated with a light indoor workout or a swim. ☀️"
        case .hurricane:
            return "With a hurricane outside, safety comes first. Let's try some calming yoga indoors when it's safe to do so. 🌀"
        case .isolatedThunderstorms:
            return "Thunderstorms can be invigorating! Let's channel that energy into a vigorous indoor routine. ⛈️"
        case .mostlyClear:
            return "The sun's peeking through! This calls for a leisurely bike ride, don't you think? 🚴‍♀️"
        case .mostlyCloudy:
            return "A little cloud cover makes for cooler conditions. Ideal for a refreshing run, wouldn't you agree? 🌥️"
        case .partlyCloudy:
            return "With a bit of sun and a bit of cloud, it's the perfect balance for an outdoor workout. ⛅"
        case .rain:
            return "Rain can't dampen our spirit. Suit up and enjoy the fresh, rainy air with a brisk walk! ☔"
        case .scatteredThunderstorms:
            return "With the thunder rumbling, it's a perfect time for an intense indoor workout. ⛈️"
        case .sleet:
            return "With sleet coming down, let's keep cozy and fit with some indoor Pilates. ❄️"
        case .smoky:
            return "With smoke in the air, let's switch to indoor activities. How about a high-energy dance workout? 💃"
        case .snow:
            return "A blanket of snow outside calls for some fun! Bundle up for a walk or snow sports. ❄️"
        case .strongStorms:
            return "Storms outside? Let's create a storm inside with an intense cardio session. 🌩️"
        case .sunFlurries:
            return "Sunlight and snowflakes, a beautiful combo! A perfect day for a winter hike. 🌨️"
        case .sunShowers:
            return "Sun showers are magical! Let's take a scenic walk and enjoy this rare weather phenomenon. 🌦️"
        case .thunderstorms:
            return "Let's use the energy from the thunderstorms for an electrifying indoor cycling session! ⛈️"
        case .tropicalStorm:
            return "During this tropical storm, let's stay safe and stick to indoor workouts. How about a calming Yoga session? 🌀"
        case .windy:
            return "With the wind at your back, you're unstoppable! Get out there and make the most of this energizing breeze. 🌬️"
        case .wintryMix:
            return "The weather may be a mixed bag, but our commitment isn't. Let's keep fit with some indoor yoga! 🌨️"
        @unknown default:
            return "The sky's clear and the air is fresh. Let's lace up those shoes and hit the pavement! 🏃‍♀️"
        }
    }
}
