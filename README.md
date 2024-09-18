# R-inventory-dashboard


Restaurant Inventory Management Dashboard
Overview

This R project involves developing an interactive dashboard to analyze and visualize restaurant inventory data. The dashboard is created using the Shiny package in R and provides various analyses including:

    Total Demand Distribution: An overview of the total demand for different food items.
    Weather/Position in the Week Analysis: Insights into how demand for specific products varies with different weather conditions and days of the week.
    Change Over Time Analysis: Analysis of demand trends over years, months, and days of the week.

Project Components

    Data Preparation:
        Data is read from a CSV file and cleaned, including handling decimal points and reshaping the data for analysis.
        Categorical variables related to weather and time are created for detailed analysis.

    Shiny App:
      Interactive UI with Tabs for Different Analyses

      - Total Demand Distribution: Provides a pie chart or similar visualization of the distribution of total demand across different food items.
      - Weather/Position in the Week Analysis: Includes plots to analyze demand based on various weather conditions and positions in the week (e.g., working days, weekends,          holidays).
      - Change Over Time Analysis: Offers insights into how demand changes over different time spans, such as by year, month, or weekday, with detailed visualizations for            various food items.

      Features:

      - Interactive Tabs: Navigate between different types of analyses with ease.
      - Plots: Visualize data through various plots for total demand distribution, weather/position in the week, and time-based changes.
      - Insights: Gain insights into totals and averages to better understand demand patterns.

    Data File:
        dataInventoryManagementRestaurant.csv: The raw data file containing inventory and weather information.

    Output File:
        inventories.xlsx: The reshaped data saved in Excel format for further analysis or reporting.

Requirements

    R: The programming language used for data analysis and visualization.
    R Packages: The project uses the following R packages:
        dplyr
        ggplot2
        tidyr
        lubridate
        shiny
        openxlsx
        RColorBrewer (for color palettes in plots)

Installation

To install the required R packages, run the following commands in your R console:

r

install.packages(c("dplyr", "ggplot2", "tidyr", "lubridate", "shiny", "openxlsx", "RColorBrewer"))

Usage

    Load Data: Make sure the data file dataInventoryManagementRestaurant.csv is available in the specified path (C:/Users/krzys/Desktop/R language/Project/dataInventoryManagementRestaurant.csv).

    Run the Code:
        Save the provided R script in a file (e.g., app.R).
        Open RStudio or another R IDE.
        Set the working directory to the location of your R script.
        Run the script to start the Shiny application.

r

source("app.R")

    Interact with the Dashboard:
        Total Demand Tab: View the total demand distribution of various food items.
        Weather/Position in the Week Analysis Tab: Analyze demand based on weather conditions and days of the week.
        Change Over Time Analysis Tab: Examine how demand changes over different time frames (year, month, day).

Data Description

    DEMAND_DATE: Date of the recorded demand.
    FOOD_ITEM: Type of food item (e.g., SQUID, FISH, SHRIMPS, etc.).
    DEMAND: The quantity of food item demanded.
    WIND, CLOUD_COVER, RAINFALL, SUN, AIR_TEMP: Weather-related variables.
    ISHOLIDAY, WEEKEND: Indicates if the day is a holiday or weekend.

Contributions

    Krzysztof Piotrowski

License

This project is licensed under the MIT License. See the LICENSE file for details.

Contact

For any questions or issues, please contact krzysztof.piotrowski.in@gmail.com
