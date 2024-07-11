// ==UserScript==
// @name         Bloxflip Crash Value Extractor with Enhanced Predictor and UI
// @namespace    http://tampermonkey.net/
// @version      1.8
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
            name: "Safe Predictor (Simple MA)",
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

    let selectedPredictor = predictors.simpleAverage; // Default predictor

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
        <div>
            <label for="predictorSelect">Select Predictor:</label>
            <select id="predictorSelect" style="font-size: 14px;">
                ${Object.keys(predictors).map(key => `<option value="${key}">${predictors[key].name}</option>`).join('')}
            </select>
        </div>
        <div id="crashValues"></div>
        <div id="crashPrediction"></div>
        <div id="gameCoefficient"></div> <!-- Display game coefficient here -->
    `;
        document.body.appendChild(uiContainer);

        // Event listener for predictor selection
        const predictorSelect = document.getElementById('predictorSelect');
        predictorSelect.addEventListener('change', function() {
            selectedPredictor = predictors[this.value];
            extractValues(); // Refresh values with new predictor
        });
    }


    // Function to update the UI with new values and prediction
    function updateUI(prediction) {
        const predictionContainer = document.getElementById('crashPrediction');
        const coefficientContainer = document.getElementById('gameCoefficient');

        predictionContainer.innerHTML = `<strong>Predicted Next Crash Value:</strong> ${prediction}`;
        coefficientContainer.innerHTML = `<strong>Current Payout:</strong> ${getGameCoefficient()}`;
    }

    // Function to extract and print the values
    function extractValues() {
        const elements = document.querySelectorAll('.gameLatest.gameLatestHorizontal.lastestHistory .gameLatestItem');
        let values = [];

        elements.forEach(element => {
            const value = parseFloat(element.textContent);
            if (!isNaN(value) && value <= 5) { // Check if value is a valid number and <= 5
                values.push(value);
            }
        });

        // Call the selected predictor function with the extracted values
        const prediction = selectedPredictor.predict(values);

        // Update the UI with the new values and prediction
        updateUI(prediction);
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
