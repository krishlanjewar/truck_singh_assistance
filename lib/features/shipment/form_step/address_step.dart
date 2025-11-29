import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class Place {
  final String description;
  final double lat;
  final double lng;

  Place({
    required this.description,
    required this.lat,
    required this.lng,
  });
}

class AddressStep extends StatelessWidget {
  final Place? pickupPlace;
  final Place? dropPlace;
  final VoidCallback onPickupSearch;
  final VoidCallback onDropSearch;
  final VoidCallback onPickupMapPick;
  final VoidCallback onDropMapPick;
  final Widget progressBar;

  const AddressStep({
    Key? key,
    required this.pickupPlace,
    required this.dropPlace,
    required this.onPickupSearch,
    required this.onDropSearch,
    required this.onPickupMapPick,
    required this.onDropMapPick,
    required this.progressBar,
  }) : super(key: key);

  Widget _addressField(
      String label,
      Place? place,
      VoidCallback onSearch,
      VoidCallback onMapPick,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            "$label *",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),

        /// Selectable address field
        InkWell(
          onTap: onSearch,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
            ),
            child: InputDecorator(
              decoration: InputDecoration(
                suffixIcon: IconButton(
                  onPressed: onMapPick,
                  tooltip: 'select_on_map'.tr(),
                  icon: const Icon(Icons.location_on),
                  color: Colors.orange,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 15,
                  horizontal: 10,
                ),
              ),
              child: Text(
                place?.description ?? 'tap_to_select_address'.tr(),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          progressBar,
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'pickup_delivery'.tr(),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),

          _addressField(
            'pickup_location'.tr(),
            pickupPlace,
            onPickupSearch,
            onPickupMapPick,
          ),

          const SizedBox(height: 20),

          _addressField(
            'dropoff_location'.tr(),
            dropPlace,
            onDropSearch,
            onDropMapPick,
          ),
        ],
      ),
    );
  }
}