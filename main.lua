// ==UserScript==
// @name         Bloxflip Crash Value Extractor with Enhanced Predictor and UI
// @namespace    http://tampermonkey.net/
// @version      1.9
// @description  Extract and print crash game values from Bloxflip, with an enhanced crash predictor and a selectable UI
// @author       ChatGPT
// @match        https://bloxflip.com/crash
// @grant        none
// ==/UserScript==

(function() {
    'use strict';

    // Function to calculate Exponential Moving Average (EMA)
    function calculateEMA(values, period) {
        const alpha = 2 / (period + 1);
        let ema = values[0]; // Initial EMA is the first value

        for (let i = 1; i < values.length; i++) {
            ema = alpha * values[i] + (1 - alpha) * ema;
        }

        return ema;
    }

    // Function to fetch the game coefficient
    function getGameCoefficient() {
        const coefficientElement = document.querySelector('.crash_crashGameCoefficient___OC_b');
        if (coefficientElement) {
            const coefficientText = coefficientElement.textContent.trim();
            return coefficientText;
        } else {
            console.error('Element with class "crash_crashGameCoefficient___OC_b" not found.');
            return null;
        }
    }

    // Predictor methods
    const predictors = {
        simpleAverage: {
            name: "Simple Moving Average",
            predict: function(values) {
                if (values.length < 2) return "Not enough data";

                const windowSize = 5; // Number of previous values to consider (adjust as needed)
                const recentValues = values.slice(-windowSize); // Consider all values for SMA
                const average = recentValues.reduce((a, b) => a + b, 0) / recentValues.length;

                return average.toFixed(2);
            }
        },
        exponentialSmoothing: {
            name: "Exponential Smoothing",
            predict: function(values) {
                if (values.length < 2) return "Not enough data";

                const alpha = 0.2; // Smoothing factor (adjust as needed)
                let forecast = values[values.length - 1]; // Initial forecast

                for (let i = 1; i < values.length; i++) {
                    forecast = alpha * values[i] + (1 - alpha) * forecast;
                }

                return forecast.toFixed(2);
            }
        },
        medianPredictor: {
            name: "Median Predictor",
            predict: function(values) {
                if (values.length < 2) return "Not enough data";

                // Sort values and find the median
                const sortedValues = values.slice().sort((a, b) => a - b);
                const middle = Math.floor(sortedValues.length / 2);
                const median = sortedValues.length % 2 === 0 ?
                               (sortedValues[middle - 1] + sortedValues[middle]) / 2 :
                               sortedValues[middle];

                return median.toFixed(2);
            }
        },
        weightedAverage: {
            name: "Weighted Average",
            predict: function(values) {
                if (values.length < 2) return "Not enough data";

                // Calculate weighted average based on frequency of occurrence
                const valueCount = {};
                values.forEach(value => {
                    if (valueCount[value]) {
                        valueCount[value]++;
                    } else {
                        valueCount[value] = 1;
                    }
                });

                let totalWeight = 0;
                let weightedSum = 0;

                for (const value in valueCount) {
                    const weight = valueCount[value];
                    totalWeight += weight;
                    weightedSum += value * weight;
                }

                const weightedAverage = weightedSum / totalWeight;
                return weightedAverage.toFixed(2);
            }
        },
        lowPredictor: {
            name: "Low Predictor",
            predict: function(values) {
                if (values.length < 2) return "Not enough data";

                const windowSize = 5; // Number of previous values to consider (adjust as needed)
                const recentValues = values.slice(-windowSize).filter(value => value <= 4); // Filter values <= 4
                const average = recentValues.reduce((a, b) => a + b, 0) / recentValues.length;

                // Ensure the predicted value is lower than the average
                const lowPrediction = Math.max(1, average - 0.5); // Adjust the offset as needed

                return lowPrediction.toFixed(2);
            }
        },
        safePredictor: {
            name: "Safe Predictor",
            predict: function(values) {
                if (values.length < 2) return "Not enough data";

                const windowSize = 5; // Number of previous values to consider (adjust as needed)
                const recentValues = values.slice(-windowSize); // Get the last 'windowSize' values
                const average = recentValues.reduce((a, b) => a + b, 0) / windowSize;

                // Ensure the predicted value is not too low
                const safePrediction = Math.max(1.2, average); // Adjust the floor value as needed

                return safePrediction.toFixed(2);
            }
        },
        macd: {
            name: "MACD",
            predict: function(values) {
                if (values.length < 3) return "Not enough data";

                // Calculate the MACD
                const shortTerm = 5; // Short-term EMA period
                const longTerm = 10; // Long-term EMA period
                const signalLine = 3; // Signal line period

                const shortEMA = calculateEMA(values, shortTerm);
                const longEMA = calculateEMA(values, longTerm);

                const MACDLine = shortEMA - longEMA;
                const signalEMA = calculateEMA([MACDLine], signalLine);

                return Math.max(1, signalEMA).toFixed(2); // Ensure prediction is at least 1
            }
        },
    };

    // Function to create the UI
    function createUI() {
        const uiContainer = document.createElement('div');
        uiContainer.id = 'crashPredictorUI';
        uiContainer.style.position = 'fixed';
        uiContainer.style.bottom = '10px'; // Position at the bottom
        uiContainer.style.left = '10px'; // Position at the left
        uiContainer.style.padding = '5px'; // Increase padding for larger UI
        uiContainer.style.width = '300px'; // Set a wider width
        uiContainer.style.backgroundColor = 'rgba(0, 0, 0, 0.8)';
        uiContainer.style.color = 'white';
        uiContainer.style.borderRadius = '10px'; // Increase border radius for rounded corners
        uiContainer.style.zIndex = '100000'; // Set a high z-index to ensure it's above everything
        uiContainer.style.fontFamily = 'Arial, sans-serif';
        uiContainer.style.fontSize = '14px'; // Adjust font size as needed
        uiContainer.innerHTML = `
            <h3 style="font-size: 18px;">Crash Predictor</h3>
            <div id="crashValues"></div>
            <div id="crashPrediction"></div>
            <div id="conf"></div>
            <div id="tenper"></div>
            <div id="gameCoefficient"></div> <!-- Display game coefficient here -->
        `;
        document.body.appendChild(uiContainer);
    }

    // Function to update the UI with new values and predictions
    function updateUI(averagePrediction, confidenceLevel, tenper) {
        const predictionContainer = document.getElementById('crashPrediction');
        const coefficientContainer = document.getElementById('gameCoefficient');
        const conf = document.getElementById('conf');
        const tenperc = document.getElementById('tenper');

        if (!predictionContainer || !coefficientContainer) {
            console.error('UI containers not found.');
            return;
        }

        // Update prediction container with text content
        predictionContainer.textContent = `Predicted Next Crash Value: ${averagePrediction.toFixed(2)}`;

        // Update confidence level container with text content
        conf.textContent = `Confidence: ${confidenceLevel.toFixed(2)}`;

        // Update 10% value container with text content
        tenperc.textContent = `10% Of Total: ${tenper.toFixed(2)}`;

        // Update coefficient container with text content
        coefficientContainer.textContent = `Current Payout: ${getGameCoefficient()}`;
    }

    function extractValues() {
        let element = document.querySelector('.text_text__fMaR4.text_regular16__7x_ra span');
        let textContent = element.innerText.trim(); // Get the trimmed text content
        let tenper = parseFloat(textContent) / 10; // Convert to number and divide by 10


        const elements = document.querySelectorAll('.gameLatest.gameLatestHorizontal.lastestHistory .gameLatestItem');
        let values = [];

        elements.forEach(element => {
            const value = parseFloat(element.textContent);
            if (!isNaN(value) && value <= 5) { // Check if value is a valid number and <= 5
                values.push(value);
            }
        });

        // Call all predictor functions with the extracted values
        const predictions = [];
        for (const key in predictors) {
            if (Object.prototype.hasOwnProperty.call(predictors, key)) {
                predictions.push(predictors[key].predict(values));
            }
        }

        // Calculate the weighted average of all predictions
        const validPredictions = predictions.filter(p => !isNaN(p));
        let sumWeightedPredictions = 0;
        let totalWeight = 0;

        validPredictions.forEach((prediction, index) => {
            // Adjusted weight calculation
            const weight = 1 / (index + 1); // Linear decrease in weight
            sumWeightedPredictions += prediction * weight;
            totalWeight += weight;
        });

        let averagePrediction = sumWeightedPredictions / totalWeight;

        // Normalize predictions to range between 0 and 5
        averagePrediction = Math.min(Math.max(averagePrediction, 0), 5);

        // Adjusted confidence level calculation
        let confidenceLevel = 0;
        if (validPredictions.length > 0) {
            const maxPrediction = Math.max(...validPredictions);
            confidenceLevel = (averagePrediction / maxPrediction) * 100; // Adjust multiplier as needed
        }

        // Update the UI with the average prediction and confidence level
        updateUI(averagePrediction, confidenceLevel, tenper);
    }

    // Function to start the loop
    function startLoop() {
        setInterval(() => {
            extractValues();
        }, 10); // Update every 5 seconds
    }

    // Wait for the page to load and elements to be available
    window.addEventListener('load', () => {
        // Create the UI
        createUI();

        // Start the loop
        startLoop();
    });
})();
